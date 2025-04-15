; Section for supress warning
SECTION .note.GNU-stack noalloc noexec nowrite progbits

SECTION .data   ;Declare variables
    Message: DB "Press (or hold) key to play note (A - K)", 10
    Message_len: EQU $-Message
    
    ;Audio settings ALSA, and melody settings
    FreqTable:                      ;Declare frequency table
        DQ 2.0548023848490921e-1    ;C
        DQ 2.3064376937686967e-1    ;D
        DQ 2.5888887780455583e-1    ;E
        DQ 2.7428321157402019e-1    ;F
        DQ 3.0787249548024787e-1    ;G
        DQ 3.4557519189487729e-1    ;A
        DQ 3.8789503773922857e-1    ;B
        DQ 4.1096047696981880e-1    ;C'

    Scale: DQ 2000  ;Scaling to convert to audible frequency
    Sample_Rate: DD 44100   ;Set sampling rate
    Segment_MS: EQU 40   ;Duration of each audio segment in ms (timing each note play, lower more smooth but more CPU)
    Amplitude: EQU 12000 ;16 bit signed amplitude (How loud the note Max: 32767)
    Channels: DD 2   ;1: Mono, 2: Stereo
    Alsa_device: DB "hw:0,0", 0 ;Alsa device name
    SND_PCM_STREAM_PLAYBACK: EQU 0
    SND_PCM_FORMAT_S16_LE: EQU 2
    SND_PCM_ACCESS_RW_INTERLEAVED: EQU 3

    ;Terminal raw mode settings
    TCGETS: EQU 21505
    TCSETS: EQU 21506

    timespec:
        tv_sec: DD 0    ; Seconds
        tv_nsec: DD 10000000 ;Nano seconds (10 ms)

    ;Key map
    Key_map: DB 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k'
    Note_map: DB 0, 1, 2, 3, 4, 5, 6, 7

SECTION .bss    ;Uninitialized data section / memory reserve
    Input_buff: RESB 1   ; Buffer for keyboard input
    Audio_fd: RESB 1 ;File descriptor for audio file
    Phase_rad: RESQ 1    ;Current phase increment (Rad/sample)
    Last_key: RESB 1 ;Store last key value (0 if None)
    Phase_acc: RESQ 1    ;Phase accumulator (64 bit precision)
    Alsa_handle: RESD 1 ;Alsa handle param
    Alsa_params: RESD 1 ;Alsa param
    Alse_buffer: RESD 1 ;Alsa buffer
    Samples_per_segment: EQU (44100 * Segment_MS / 1000)  ; = 1764 samples
    Samples_per_frame: EQU Samples_per_segment * Channels
    Sample_buffer: RESW Samples_per_frame  ; 32-bit samples
    Repeat_delay: RESD 1
    Termios:
        c_iflag RESD 1  ;Input mode flags
        c_oflag RESD 1  ;Output mode flags
        c_cflag RESD 1  ;Control mode flags
        c_lflag RESD 1  ;Local mode flags (ICANON and ECHO)
        c_line RESD 1   ;Line discipline
        c_cc RESB 64    ;Control character

    Old_termios: RESB 128   ;To store default termios settings


SECTION .text   ;Code section
    BITS 32 ;Explicit 32-bit only
    ;Get all alsa settings
    extern snd_pcm_open, snd_pcm_close, snd_pcm_hw_params_malloc
    extern snd_pcm_hw_params_any, snd_pcm_hw_params_set_access
    extern snd_pcm_hw_params_set_format, snd_pcm_hw_params_set_channels
    extern snd_pcm_hw_params_set_rate_near, snd_pcm_hw_params
    extern snd_pcm_writei, snd_pcm_prepare, snd_pcm_hw_params_free
    extern snd_strerror
    global main   ;Set starting point

main:         ;main()
    CALL Set_raw_mode   ;Set raw_mode
    MOV EAX, 4  ;Call sys_write
    MOV EBX, 1  ;stdout
    MOV ECX, Message    ;message content
    MOV EDX, Message_len ;message_len
    INT 80H ;System interupt (sys_call)

    CALL Init_alsa  ;Setting up Alsa device
    CMP EAX, 0      ;Compare if Alsa sub routine return 0 == success
    JLE Error_exit  ;Jump if less than zero

    MOV EAX, [Alsa_handle] ; Load ALSA handle
    MOV [Audio_fd], EAX    ; Save it as file descriptor equivalent

    JMP main_loop

Set_raw_mode:
    ;Switch stdin to raw input mode
    MOV EAX, 54     ;sys_ioctl
    MOV EBX, 0      ;stdin
    MOV ECX, TCGETS ;Get terminal attributes
    MOV EDX, Termios    ;Pointer to output termios struct
    INT 80H             ;sys_call

    MOV ESI, Termios    ;Source pointer to current settings
    MOV EDI, Old_termios    ;Destination pointer to old settings
    MOV ECX, 72             ;Number byte to copy
    REP MOVSB               ;Copy termios struct byte by byte

    ;-8 = 0xFFFFFFF8 = ~(1 << 0 | 1<<1 | 1<<2)
    ;~(ICANON | ECHO | ISIG)
    AND dword [c_lflag], -8 ;Disable line buffering and input echo (clear bits 1 (ICANON) and 2 (ECHO)
    
    ;Set minimum required character to 1
    MOV byte [c_cc + 6], 1  ;VMIN
    MOV byte [c_cc + 5], 0  ;VTIME

    ;ioctl(stdin, TCSETS, &Termios)
    MOV EAX, 54     ;sys_ioctl
    MOV EBX, 0      ;stdin
    MOV ECX, TCSETS ;Set terminal attributes
    MOV EDX, Termios    ;Pointer to modified settings
    INT 80H             ;sys_call
    RET ;Return to function

main_loop:
    ;Check keyboard input if no continue
    CALL Check_keyboard

    CMP byte [Last_key], 0  ;check if last key (memory value) == 0
    JE Short_pause          ;Jump if [Last_key] == 0

    CMP dword [Repeat_delay], 0 ;Check if Repeat_delay == 0
    JNE Skip_play       ;Jump if [Repeat_delay]  != 0

    CALL Play_note_segment  ;Play current note
    MOV dword [Repeat_delay], 3 ;Play once every 3 loop
    JMP main_loop   ;loop again

Skip_play:
    DEC dword [Repeat_delay]
    JMP main_loop

Short_pause:
    ;Sleep threading for 10ms to reduce CPU usage when it's idle
    MOV EAX, 162    ;sys_sleep
    MOV EBX, timespec  ;Declared time struct (set how long the CPU will sleep) 
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
    
    MOV AL, [Input_buff]
    MOV ESI, Key_map
    MOV ECX, 8

Find_key:
    CMP AL, [ESI]
    JE Key_found
    INC ESI
    LOOP Find_key

    JMP End_check

Key_found:
    MOV [Last_key], AL
    JMP End_check

Invalid_key:
    MOV byte [Last_key], 0  ;Treat it as a key release
    JMP End_check

End_check:
    POPA    ;Return all stored register value from stack back to register
    RET ;Return to last jump

;Audio generation, from mathematically generated sine wave
Play_note_segment:
    PUSHA   ;Push current registers value to stack
    MOV ECX, Samples_per_segment ;Get pre-calculated sample per segment
    MOV EDI, Sample_buffer  ;EDI = start of sample buffer

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
    FSTP qword [Phase_rad]  ;Store phase_rad in memory (pop ST0)
    FLD qword [Phase_acc]   ;Load 64-bit phase accumulator

Generate_samples:
    FLD ST0     ;Duplicate current phase (ST0 -> ST1, ST0 = phase)
    FSIN        ;ST0 = sin(phase)
    
    MOV EAX, Amplitude  ;Prepare amplitude for multipication
    PUSH EAX    ;Store on stack for FPU access
    FIMUL dword [ESP]   ;ST0 = sin(phase) * AMPLITUDE
    ADD ESP, 4  ;Clean up stack
    
    FISTP word [EDI]    ;Write to left channel
    MOV AX, [EDI]       ;Duplicate to right
    MOV [EDI + 2], AX   ;Write right channel
    ADD EDI, 4          ; Advance buffer pointer by 4

    FLD dword [Phase_rad]   ;Load phase increment (ST0)
    FADDP ST1, ST0          ;ST1 = ST1 + ST0, pop ST0 (Phase_rad += increment)

    FLDPI   ;Load pi to ST0
    FADD ST0, ST0   ;ST0 = 2pi
    FCOMIP ST1     ;Compare 2pi (ST0) with phase (ST1), pop ST0

    JA Phase_wrap  ;Jump if ST0 <= ST1
    JMP Phase_ok    ;else continue

Phase_wrap:
    FLDPI   ;Load pi to ST0
    FADD ST0, ST0   ;ST0 = 2pi
    FSUB ST1, ST0   ;Phase -= 2pi

Phase_ok:
    LOOP Generate_samples   ;Decrement ECX, jump if not zero

    FSTP qword [Phase_acc]  ;Store 64-bit phase accumulator, pop ST0

    ; snd_pcm_writei(&handle, sample_buffer, sample_per_segment)
    PUSH Samples_per_segment    ;Sample per segment
    PUSH Sample_buffer          ;Sample buffer
    PUSH dword [Alsa_handle]    ;Alsa handle
    CALL snd_pcm_writei         ;Call ALSA write function
    ADD ESP, 12                 ;Clear the stack (3 args * 4 byte)
    
    CMP EAX, -32    ;Check if ALSA encounter underrun (EPIPE = -32)
    JE Underrun     ;Jump if EAX == -32

    CMP EAX, -16    ;Check if ALSA encounter busy (EBUSY = -16)
    JE Device_busy  ;Jump if EAX == -16

    TEST EAX, EAX   ;Check other lingering error
    JS Error        ;Jump if sign flag is set (-EAX)

    POPA    ;Restore all register value
    RET     ;Return from subroutine

Device_busy:
    MOV EAX, 162
    MOV EBX, timespec
    MOV ECX, 0
    INT 80H
    RET

Underrun:
    ; snd_pcm_prepare(handle)
    PUSH dword [Alsa_handle]    ;PCM handle
    CALL snd_pcm_prepare        ;Prepare device
    ADD ESP, 4                  ;Clean up stack
    TEST EAX, EAX               ;Test return value
    JNZ Error                   ;Jump if error
    JMP Play_note_segment       ;Retry

Init_alsa:
    MOV dword [Alsa_handle], 0  ;Clear ALSA device
    MOV dword [Alsa_params], 0  ;Clear hardware parameters pointer

    ; snd_pcm_open(&handle, device_name, SND_PCM_STREAM_PLAYBACK, 0)
    PUSH 0  ;Mode (0 default)
    PUSH SND_PCM_STREAM_PLAYBACK    ;Stream type (playback)
    PUSH Alsa_device    ;Device name
    PUSH Alsa_handle    ;Pointer to store handle
    CALL snd_pcm_open   ;Call ALSA open function
    ADD ESP, 16         ;Clean up stack (4 args * 4 bytes)
    CMP EAX, 0          ;Check return value
    JNZ Error           ;Jump if error

    ; snd_pcm_hw_params_malloc(&params)
    LEA EAX, [Alsa_params]  ;EAX = &Alsa_params
    PUSH EAX    ;push &Alsa_params (i.e., snd_pcm_hw_params_t **)
    CALL snd_pcm_hw_params_malloc   ;Allocate params structure
    ADD ESP, 4      ;Clean up stack
    CMP EAX, 0      ;Check return value
    JNZ Error       ;Jump if error

    ; snd_pcm_hw_params_any(handle, params)
    PUSH dword [Alsa_params]    ;Hardware params
    PUSH dword [Alsa_handle]    ;PCM device handle
    CALL snd_pcm_hw_params_any  ;Init params
    ADD ESP, 8                  ;Clean up stack
    TEST EAX, EAX               ;Test return value
    JNZ Error                   ;Jump if error

    ; snd_pcm_hw_params_set_access(handle, params, SND_PCM_ACCESS_RW_INTERLEAVED)
    PUSH SND_PCM_ACCESS_RW_INTERLEAVED  ;Access type (interleaved rw)
    PUSH dword [Alsa_params]            ;Hardware params
    PUSH dword [Alsa_handle]            ;PCM handle
    CALL snd_pcm_hw_params_set_access   ;Set access type
    ADD ESP, 12                         ;Clean up stack
    TEST EAX, EAX                       ;Test return value
    JNZ Error                           ;Jump if error

    ; snd_pcm_hw_params_set_format(handle, params, SND_PCM_FORMAT_S16_LE)
    PUSH SND_PCM_FORMAT_S16_LE          ;Sample format
    PUSH dword [Alsa_params]            ;Hardware params
    push dword [Alsa_handle]            ;PCM handle
    CALL snd_pcm_hw_params_set_format   ;Set format
    ADD ESP, 12                         ;Clean up stack
    TEST EAX, EAX                       ;Test return value
    JNZ Error                           ;Jump if error

    ; snd_pcm_hw_params_set_channels(handle, params, channels)
    MOV EAX, [Channels]         ;Get channels value
    PUSH EAX                    ;Push channels
    PUSH dword [Alsa_params]    ;Hardware params
    PUSH dword [Alsa_handle]    ;PCM handle
    CALL snd_pcm_hw_params_set_channels ;Set channels
    ADD ESP, 12     ;Clean up stack
    TEST EAX, EAX   ;test return value
    JNZ Error       ;Jump if error

    ; snd_pcm_hw_params_set_rate_near(handle, params, &Sample_Rate, 0)
    PUSH 0      ;Direction (0 = exact/nearest)
    LEA EAX, [Sample_Rate]  ;Load the variable memory to EAX
    PUSH EAX    ;Push memory address (Sample rate (44100)) to stack
    PUSH dword [Alsa_params]    ;Hardware params
    PUSH dword [Alsa_handle]    ;PCM handle
    CALL snd_pcm_hw_params_set_rate_near    ;Set sample rate
    ADD ESP, 16         ;Clean up stack
    TEST EAX, EAX       ;Test return value
    JNZ Error           ;Jump if error

    ; snd_pcm_hw_params(handle, params)
    PUSH dword [Alsa_params]    ;Push Alsa parameter
    PUSH dword [Alsa_handle]    ;Push Alsa handle
    CALL snd_pcm_hw_params      ;Set all previous config to the device
    ADD ESP, 8                  ;Clean the stack
    TEST EAX, EAX               ;Test return value
    JNZ Error                   ;Jump if error

    ; snd_pcm_prepare(handle)
    PUSH dword [Alsa_handle]    ;PCM handle
    CALL snd_pcm_prepare        ;Prepare device
    ADD ESP, 4                  ;Clean up stack
    TEST EAX, EAX               ;Test return value
    JNZ Error                   ;Jump if error

    RET                         ;Return to function

Error:
    ;Push return value from ALSA
    PUSH EAX
    CALL Print_alsa_error
    RET

Print_alsa_error:
    MOV EBX, EAX    ; EBX = EAX (Copy error code from the ALSA)
    PUSH EBX        ; Push error code to stack
    ; snd_strerror(int errnum)
    CALL snd_strerror   ;Get ALSA error string
    ADD ESP, 4     ;Clean up stack

    MOV ECX, EAX    ;Set buffer for the error message
    MOV EAX, 4      ;sys_write
    MOV EBX, 1      ;stdout
    MOV EDX, 100    ;Set buffer size = 100
    INT 80H         ;sys_call
    RET

Alsa_fail:
    CMP dword [Alsa_handle], 0      ;Check if handle exists
    JE Error_exit                   ;Skip close if no handle
    PUSH dword [Alsa_handle]        ;PCM handle to close
    CALL snd_pcm_close              ;Close device
    ADD ESP, 4                      ;Clean up stack
    MOV dword [Alsa_handle], 0      ;Set [Alsa_handle] = 0
    JMP Error_exit                  ;Return error

Close_and_exit:
    CMP dword [Alsa_handle], 0     ;Compare if [Alsa_handle] == 0
    JE Ok_exit                     ;Jump if equal
    PUSH dword [Alsa_handle]       ;PCM handle to close
    CALL snd_pcm_close             ;Close device
    ADD ESP, 4                     ;Clean up stack
    MOV dword [Alsa_handle], 0     ;Set [Alsa_handle] = 0
    JMP Ok_exit

Error_exit:
    MOV EBX, 1  ;Set return 1
    JMP exit    ;Jump to exit

Ok_exit:
    XOR EBX, EBX    ;Set return 0
    JMP exit        ;Jump to exit

Restore_terminal:
    MOV ESI, Old_termios    ;Source pointer to old settings
    MOV EDI, Termios        ;Destination to current settings
    MOV ECX, 72             ;Number byte to copy
    REP MOVSB               ;Copy termios struct byte by byte

    MOV EAX, 54             ;sys_ioctl
    MOV EBX, 0              ;stdin
    MOV ECX, TCSETS         ;Set terminal attributes
    MOV EDX, Termios        ;Pointer to restored settings
    INT 80H                 ;sys_call
    RET                     ;Return to function

exit:
    ; snd_pcm_hw_params_free(&Alsa_params)
    PUSH dword [Alsa_params]    ;Push alsa_params to stack
    CALL snd_pcm_hw_params_free ;Free hardware parameters
    ADD ESP, 4                  ;Clear stack

    CALL Restore_terminal   ;Set terminal setting to default
    MOV EAX, 1  ;sys_exit
    INT 80H ;sys_call