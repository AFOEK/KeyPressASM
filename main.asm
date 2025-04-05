SECTION .data   ;Declare variables
    Message: DB "Press (or hold) key to play note (A - K)", 10
    Message_len: EQU $-Message

    Debug_Msg: DB "OK !", 10
    Debug_Msg_len: EQU $-Debug_Msg

    Message_err: DB "Error !",10
    Message_err_len: EQU $Message_err_len

    Message_err_alsa: DB "Failed to initialized Alsa !", 10
    Message_err_alsa_len: EQU $Message_err_alsa

    FreqTable:                      ;Declare frequency table
        DQ 2.0548023848490921e-1    ;C
        DQ 2.3064376937686967e-1    ;D
        DQ 2.5888887780455583e-1    ;E
        DQ 2.7428321157402019e-1    ;F
        DQ 3.0787249548024787e-1    ;G
        DQ 3.4557519189487729e-1    ;A
        DQ 3.8789503773922857e-1    ;B
        DQ 4.1096047696981880e-1    ;C'

    Audio_dev_path: DB "/dev/snd/pcmC0D0p",0    ;Sound device path
    Scale: DQ 2000  ;Scaling to convert to audible frequency
    Sample_Rate: EQU 44100   ;Set sampling rate
    Segment_MS: EQU 40   ;Duration of each audio segment in ms (timing each note play, lower more smooth but more CPU)
    Amplitude: EQU 12000 ;16 bit signed amplitude (How loud the note Max: 32767)
    Alsa_device: db "default", 0
    SND_PCM_STREAM_PLAYBACK: EQU 1
    SND_PCM_FORMAT_S16_LE: EQU 2
    SND_PCM_ACCESS_RW_INTERLEAVED: EQU 3

timespec:
    tv_sec: DD 0    ; Seconds
    tv_nsec: DD 10000000 ;Nano seconds (10 ms)

SECTION .bss    ;Uninitialized data section / memory reserve
    Input_buff: RESB 1   ; Buffer for keyboard input
    Audio_fd: RESB 1 ;File descriptor for audio file
    Phase_rad: RESB 1    ;Current phase increment (Rad/sample)
    Last_key: RESB 1 ;Store last key value (0 if None)
    Phase_acc: RESB 1    ;Phase accumulator (64 bit precision)
    Alsa_handle: RESD 1 ;Alsa handle param
    Alsa_params: RESD 1 ;Alsa param
    Alse_buffer: RESD 1 ;Alsa buffer


SECTION .text   ;Code section
    ;Get all alsa settings
    extern snd_pcm_open, snd_pcm_close, snd_pcm_hw_params_malloc
    extern snd_pcm_hw_params_any, snd_pcm_hw_params_set_access
    extern snd_pcm_hw_params_set_format, snd_pcm_hw_params_set_channels
    extern snd_pcm_hw_params_set_rate_near, snd_pcm_hw_params
    extern snd_pcm_writei, snd_pcm_prepare
    global _start   ;Set starting point

_start:         ;main()
    MOV EAX, 4  ;Call sys_write
    MOV EBX, 1  ;stdout
    MOV ECX, Message    ;message content
    MOV EDX, Message_len ;message_len
    INT 80H ;System interupt (sys_call)

    ; MOV EAX, 5  ;Call sys_open
    ; MOV EBX, Audio_dev_path ;Set audio path
    ; MOV ECX, 1  ; O_WRONLY (Write only mode)
    ; MOV EDX, 0  ; No mode (Permission control flag)
    ; INT 80H ;sys_call

    CALL Init_alsa
    TEST EAX, EAX
    JNZ Error_exit

    CMP EAX, 0  ;Compare EAX (sys_open return value) == 0
    JL exit ;Jump if EAX < 0 else continue
    MOV [Audio_fd], EAX ; Set file descriptor memory value to EAX
    ;;Set non block stdin (default; stdin always terminate if )
    MOV EAX, 55 ;Call sys_fcntl
    MOV EBX, 0  ;stdin
    MOV ECX, 3  ;F_GETFL (get current flag)
    INT 80H     ;sys_call

    OR EAX, 2048    ;set O_NONBLOCK flag value
    MOV EBX, 0      ;stdin
    MOV ECX, 4      ;F_SETFL (set new flag)
    MOV EDX, EAX    ;MOV EAX (New flag value {OE EAX, 2048} to EDX)
    MOV EAX, 55     ;sys_fnctl
    INT 80H         ;sys_call

main_loop:
    ;Check keyboard input if no continue
    CALL Check_keyboard

    CMP byte [Last_key], 0  ;check if last key (memory value) == 0
    JE Short_pause          ;Jump if [Last_key] == 0

    CALL Play_note_segment  ;play current note
    JMP main_loop   ;loop again

Short_pause:
    ;Sleep threading for 10ms to reduce CPU usage when it's idle
    MOV EAX, 162    ;sys_sleep
    MOV EBX, timespec  ;declared time struct (set how long the CPU will sleep) 
    MOV ECX, 0  ;Put flag if timespec is nullable
    INT 80H ;sys_call

Check_keyboard:
    PUSHA   ;Store all current registers value to stack
    ;Capture key press (or hold)
    MOV EAX, 3  ;sys_read
    MOV EBX, 0  ;stdin
    MOV ECX, Input_buff ;set keyboard input buffer
    MOV EDX, 1  ;set size of the buffer
    INT 80H ;sys_call

    CMP EAX, 1  ;Check if sys_read return == 1 (a key was pressed)
    JNE End_check   ;Jump if sys_read != 1

    CMP byte [Input_buff], 'q'  ;Check if input buffer == 'q'
    JE Close_and_exit   ;Jump if [Input_buff] == 'q'
    ;Check key range A - K (C - C')
    CMP byte [Input_buff], 'a'  ;Check if input buffer == 'a'
    JB Invalid_key ;Jump if [Input_buffer] < 'a'
    CMP byte [Input_buff], 'k'  ;Check if input buffer == 'k'
    JA Invalid_key ;Jump if [Input_buffer] > 'k'

    MOV AL, [Input_buff]    ;Store all valid key to 16 bit register
    MOV [Last_key], AL  ;Get the last pressed key, stored to [Last_key]
    JMP End_check   ;Jump to End_check

Invalid_key:
    MOV byte [Last_key], 0  ;Treat it as a key release

End_check:
    POPA    ;Return all stored register value from stack back to register
    RET ;Return to last jump

;Audio generation, from mathematically generated sine wave

Play_note_segment:
    PUSHA   ;Push current registers value to stack

    MOV EAX, Sample_Rate    ;Set Sample rate
    MOV EBX, Segment_MS     ;Set segment timing
    MUL EBX                 ;EAX = EAX * EBX
    MOV EBX, 1000           ;Set EBX = 1000
    DIV EBX                 ;EAX = EAX / EBX (1000)
    MOV ECX, EAX            ;Set ECX = EAX

    MOVZX EAX, byte [Last_key] ;Move byte to double word (last_key) with zero extention
    SUB EAX, 'a'        ;EAX = EAX - 'a'; Convert to 0 based index
    MOV EBX, FreqTable  ;Load the frequency table to EBX
    FLD qword [EBX + EAX * 8]   ;Load 64 bit frequency from table (ST0)

    FLD qword [Scale]   ;Load scaling factor (ST0), frequency already set to ST1
    FMULP ST1, ST0      ;Multiply frequency by scale factor (ST1 = ST1 * ST0, the pop ST0)

    FLDPI   ;Load pi into ST0 (frequency moved to ST1)
    FADD ST0, ST1   ;ST0 = 2pi
    FMUL ST0, ST1   ;ST0 = 2pi * frequency
    MOV EAX, Sample_Rate    ;Set sample rate for divide
    PUSH EAX    ;Push EAX value to stack for FPU
    FIDIV dword [ESP]   ;ST0 = (2pi * frequency) / Sample_rate
    ADD ESP, 4  ;Clean up stack
    FSTP dword [Phase_rad]  ;Store phase_rad in memory (pop ST0)
    FLD qword [Phase_acc]   ;Load 64-bit phase accumulator

Generate_samples:
    FLD ST0     ;Duplicate current phase (ST0 -> ST1, ST0 = phase)
    FSIN        ;ST0 = sin(phase)
    MOV EAX, Amplitude  ;Prepare amplitude for multipication
    PUSH EAX    ;Store on stack for FPU access
    FIMUL dword [ESP]   ;ST0 = sin(phase) * AMPLITUDE
    ADD ESP, 4  ;Clean up stack
    FISTP word [Input_buff] ;Store sample in memory (input memory), pop ST0
    
    MOV EAX, 4  ;sys_write
    MOV EBX, [Audio_fd] ;Audio device file descriptor
    MOV ECX, Input_buff ;Pointer to sample data
    MOV EDX, 2  ;2 byte per sample (16 bit)
    INT 80H ;sys_call

    FLD dword [Phase_rad]   ;Load phase increment (ST0)
    FADDP ST1, ST0          ;ST1 = ST1 + ST0, pop ST0 (Phase_rad += increment)

    FLDPI   ;Load pi to ST0
    FADD ST0, ST0   ;ST0 = 2pi
    FCOMIP ST1     ;Compare 2pi (ST0) with phase (ST1), pop ST0
    JBE Phase_wrap  ;Jump if ST0 <= ST1
    JMP Phase_ok    ;else continue

Phase_wrap:
    FSUB ST0, ST0   ;Phase -= 2pi

Phase_ok:
    LOOP Generate_samples   ;Decrement ECX, jump if not zero

    FSTP qword [Phase_acc]  ;Store 64-bit phase accumulator, pop ST0
    POPA    ;Restore all register value
    RET     ;Return from subroutine

Init_alsa:
    PUSH 0
    PUSH SND_PCM_STREAM_PLAYBACK
    PUSH Alsa_device
    PUSH Alsa_handle
    CALL snd_pcm_open
    ADD ESP, 16
    TEST EAX, EAX
    JNZ Error

    PUSH Alsa_params
    CALL snd_pcm_hw_params_malloc
    ADD ESP, 4
    TEST EAX, EAX
    JNZ Error

    PUSH dword [Alsa_params]
    PUSH dword [Alsa_handle]
    CALL snd_pcm_hw_params_any
    ADD ESP, 8
    TEST EAX, EAX
    JNZ Error

    PUSH SND_PCM_ACCESS_RW_INTERLEAVED
    PUSH dword [Alsa_params]
    PUSH dword [Alsa_handle]
    CALL snd_pcm_hw_params_set_access
    ADD ESP, 12
    TEST EAX, EAX
    JNZ Error

    PUSH SND_PCM_FORMAT_S16_LE
    PUSH dword [Alsa_params]
    push dword [Alsa_handle]
    CALL snd_pcm_hw_params_set_format
    ADD ESP, 12
    TEST EAX, EAX
    JNZ Error

    PUSH 1
    PUSH dword [Alsa_params]
    PUSH dword [Alsa_handle]
    CALL snd_pcm_hw_params_set_channels
    ADD ESP, 12
    TEST EAX, EAX
    JNZ Error

    PUSH 0
    PUSH Sample_Rate
    PUSH dword [Alsa_params]
    PUSH dword [Alsa_handle]
    CALL snd_pcm_hw_params_set_rate_near
    ADD ESP, 16
    TEST EAX, EAX
    JNZ Error

    PUSH dword [Alsa_handle]
    CALL snd_pcm_prepare
    ADD ESP, 4

    XOR EAX, EAX
    RET

Error:
    MOV EAX, -1
    RET

Close_and_exit:
    ; MOV EAX, 6  ;sys_close
    ; MOV EBX, [Audio_fd] ;Audio file descriptor
    ; INT 80H ;sys_call

    PUSH dword [Alsa_handle]
    CALL snd_pcm_close
    ADD ESP, 4
    MOV EAX, 1
    XOR EBX, EBX
    INT 80H

Error_exit:
    MOV EAX, 4
    MOV EBX, 1
    MOV ECX, Message_err_alsa
    MOV EDX, Message_err_alsa_len
    INT 80H

    MOV EAX, 1
    MOV EBX, 1
    INT 80H

exit:
    MOV EAX, 1  ;sys_exit
    MOV EBX, 0  ;return 0;
    INT 80H ;sys_call