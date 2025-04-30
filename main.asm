; Section for supress warning
SECTION .note.GNU-stack noalloc noexec nowrite progbits

SECTION .data   ;Declare variables
    Message: DB "Press (or hold) key to play note (A - K)", 10
    Message_len: EQU $-Message

    Newline: DB 10
    
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

    Scale: DQ 1.0e4  ;Scaling to convert to audible frequency
    Sample_Rate: DD 44100   ;Set sampling rate
    Segment_MS: EQU 40   ;Duration of each audio segment in ms (timing each note play, lower more smooth but more CPU)
    Amplitude: DD 28000 ;16 bit signed amplitude (How loud the note Max: 32767)
    Channels: DD 2   ;1: Mono, 2: Stereo
    Alsa_device: DB "sysdefault:CARD=PCH", 0 ;Alsa device name
    SND_PCM_STREAM_PLAYBACK: EQU 0
    SND_PCM_FORMAT_S16_LE: EQU 2
    SND_PCM_ACCESS_RW_INTERLEAVED: EQU 3
    Key_pressed: DB 1
    Note_change: DB 1

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
    Sample_buffer: RESW Samples_per_frame * 2 + 4 ; 32-bit samples
    Repeat_delay: RESD 1
    Frame_per_segment: RESD 1   ;Number of frames per segment
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
    JL Error_exit  ;Jump if less than zero

    FLDZ            ;Push 0.0 to FPU stack
    FSTP qword [Phase_acc]  ;Store [Phase_acc] FPU value to memory and pop
    MOV byte [Last_key], 255
    MOV byte [Note_change], 1
    JMP main_loop   ;Jump to main_loop

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
    MOV byte [Key_pressed], 0
    CALL Check_keyboard

    CMP byte [Key_pressed], 1  ;check if key pressed (memory value) == 1
    JNE Short_pause          ;Jump if [Key_pressed] == 1

    CALL Audio_generation  ;Generate current note
    JMP main_loop   ;Loop again

Short_pause:
    ;Sleep threading for 10ms to reduce CPU usage when it's idle
    MOV EAX, 162    ;sys_sleep
    MOV EBX, timespec  ;Declared time struct (set how long the CPU will sleep) 
    MOV ECX, 0  ;Put flag if timespec is nullable
    INT 80H ;sys_call

Check_keyboard:
    ;Capture key press (or hold)
    MOV EAX, 3  ;sys_read
    MOV EBX, 0  ;stdin
    MOV ECX, Input_buff ;set keyboard input buffer
    MOV EDX, 1  ;set size of the buffer
    INT 80H ;sys_call

    CMP EAX, 1  ;Check if sys_read return == 1 (a key was pressed)
    JNE No_key   ;Jump if sys_read != 1

    PUSHA   ;Store all current registers value to stack

    CMP byte [Input_buff], 'q'  ;Check if input buffer == 'q'
    JE Close_and_exit   ;Jump if [Input_buff] == 'q'
    
    MOV AL, [Input_buff]    ;Load input to AL (Last 8 bit)
    MOV ESI, Key_map        ;Start of Key_map
    MOV EDI, Note_map       ;Start of Note_map
    MOV ECX, 8              ;Set buffer for total key

Find_key:
    CMP AL, [ESI]   ;Check if input key matches of a key in the list
    JE Key_found    ;Jump if equal
    INC ESI         ;Mov the pointer to the next key
    INC EDI         ;Move the pointer to the next note
    LOOP Find_key   ;Check again until match

    JMP Invalid_key ;jump if no match found

Key_found:
    MOV AL, [EDI]   ;Load note index from note_map
    CMP AL, [Last_key]  ;Check if last key is the same
    JNE New_note        ;Jump if AL == [Last_key]

    MOV byte [Key_pressed], 1   ;Set flag if same note
    JMP End_check

New_note:
    ;Different key pressed
    MOV byte [Note_change], 1
    MOV [Last_key], AL
    MOV byte [Key_pressed], 1
    JMP End_check

Invalid_key:
    MOV byte [Last_key], 255  ;To represent invalid key
    MOV byte [Key_pressed], 0

End_check:
    POPA    ;Return all stored register value from stack back to register

No_key:
    RET     ;Return to last jump

;Audio generation, from mathematically generated sine wave
Audio_generation:
    PUSHA   ;Push current registers value to stack
    FINIT   ;Clear and initialized FPU

    CMP byte [Note_change], 1   ;Compare [Note_change] == 1
    JNE No_reset                ;Jump if [Note_change] != 1

    FLDZ                        ;Push 0.0 to FPU stack
    FSTP qword [Phase_acc]      ;Store [Phase_acc] FPU value to memory and pop
    MOV byte [Note_change], 0   ;[Note_change] = 0

No_reset:
    MOVZX EAX, byte [Last_key] ;Note index (0-7)
    CMP EAX, 8  ;Check if in bound
    JAE Invalid_note    ;Jump if above or equal (EAX >= 8)

    MOV ECX, Samples_per_segment ;Get pre-calculated sample per frame
    MOV EDI, Sample_buffer  ;EDI = start of sample buffer
    FLD qword [FreqTable + EAX * 8]   ;Load 64 bit frequency from table (ST0) and get appropiate tone
    FLD qword [Scale]   ;Load scaling factor (ST0), frequency already set to ST1
    FMULP     ;Multiply frequency by scale factor (ST1 = ST1 * ST0, the pop ST0)

    FLDPI   ;Load pi into ST0 (frequency moved to ST1)
    FADD ST0, ST0   ;ST0 = 2pi
    FMUL   ;ST0 = 2pi * frequency
    FIDIV dword [Sample_Rate]   ;ST0 = pahse_rad
    FSTP qword [Phase_rad]  ;Store phase_rad in memory (pop ST0)
    FLD qword [Phase_acc]   ;Load current 64-bit phase accumulator

Generate_samples:
    FLD ST0     ;Duplicate current phase (ST0 -> ST1, ST0 = phase)
    FSIN        ;ST0 = sin(phase)
    FIMUL dword [Amplitude] ;ST0 = sin(phase) * AMPLITUDE
    FISTP word [EDI]    ;Store left channel sample, and write it to [EDI]
    MOV AX, [EDI]       ;Load back value from [EDI]
    MOV [EDI + 2], AX   ;Write to right channel
    ADD EDI, 4          ;Advance buffer pointer by 4

    FLD qword [Phase_rad]   ;Load phase increment (ST0)
    FADDP ST1, ST0          ;Phase_acc += Phase_rad, and pop ST0

    FLDPI   ;Load pi to ST0
    FADD ST0, ST0   ;ST0 = 2pi
    FLD ST1     ;Load 2pi (copy)
    FCOMPP      ;Compare and pop both
    FSTSW AX
    SAHF
    JBE Phase_ok    ;Jump if Phase_acc <= 2pi

    FLDPI
    FADD ST0, ST0                 ;ST0 = 2pi
    FSUBP ST1, ST0                ;ST1 = Phase_acc - 2pi → now in ST0

Phase_ok:
    LOOP Generate_samples

    FSTP qword [Phase_acc]
    CALL Write_audio
    POPA
    RET

Invalid_note:
    MOV ECX, Samples_per_frame ;Get pre-calculated sample per frame
    MOV EDI, Sample_buffer  ;EDI = start of sample buffer
    XOR EAX, EAX    ;Clear EAX
    REP STOSW       ;Store word in string repeat until CX == 0
    POPA            ;restore all value to register
    RET             ;Return to recent CALL

Write_audio:
    ;Calculate Frame_per_segment = Sample_per_segment / Channels
    MOV EAX, Samples_per_segment
    CDQ     ;Sign extend EAX into EDX:EAX
    IDIV dword [Channels] ;EAX = EAX / Channels
    MOV [Frame_per_segment], EAX ;EAX = [Frame_per_segment]

    ; snd_pcm_writei(&handle, sample_buffer, sample_per_segment)
    PUSH dword [Frame_per_segment]    ;Frame per segment
    PUSH Sample_buffer          ;Sample buffer
    PUSH dword [Alsa_handle]    ;Alsa handle
    CALL snd_pcm_writei         ;Call ALSA write function
    ADD ESP, 12                 ;Clear the stack (3 args * 4 byte)
    
    CMP EAX, -32    ;Check if ALSA encounter underrun (EPIPE = -32)
    JE Underrun     ;Jump if EAX == -32

    CMP EAX, -16    ;Check if ALSA encounter busy (EBUSY = -16)
    JE Device_busy  ;Jump if EAX == -16

    CMP EAX, [Frame_per_segment]
    JL Write_audio

    TEST EAX, EAX   ;Check other lingering error
    JS Error        ;Jump if sign flag is set (-EAX)

    JMP Play_done

Device_busy:
    MOV EAX, 162    ;sys_nanosleep
    MOV EBX, timespec   ;Time duration
    MOV ECX, 0          ;REM
    INT 80H         ;sys_call
    RET             ;Return to function

Underrun:
    ; snd_pcm_prepare(handle)
    PUSH dword [Alsa_handle]    ;PCM handle
    CALL snd_pcm_prepare        ;Prepare device
    ADD ESP, 4                  ;Clean up stack
    TEST EAX, EAX               ;Test return value
    JNZ Error                   ;Jump if error
    JMP Audio_generation       ;Retry

Play_done:
    RET                     ;Return to function

Clear_buffer:
    MOV ECX, Samples_per_segment    ;Set ECX = Samples_per_segment
    IMUL ECX, [Channels]            ;ECX = ECX * [Channels]
    MOV EDI, Sample_buffer          ;Point EDI to beginning of sample buffer
    XOR EAX,EAX                     ;EAX = 0
    REP STOSW                       ;Repeat store 0 word ECX time
    RET                             ;Return to last call

Init_alsa:
    MOV dword [Alsa_handle], 0  ;Clear ALSA device
    MOV dword [Alsa_params], 0  ;Clear hardware parameters pointer

    ; snd_pcm_open(&handle, device_name, SND_PCM_STREAM_PLAYBACK, 0)
    PUSH 0  ;Mode (0 default)
    PUSH SND_PCM_STREAM_PLAYBACK    ;Stream type (playback)
    PUSH Alsa_device    ;Device name
    LEA EAX, [Alsa_handle]  ;Get the address of Alsa_handle
    PUSH EAX            ;Pointer to store handle
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
    PUSH dword [Channels]       ;Push channels
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
    PUSH EAX        ; Push error code to stack
    CALL Print_alsa_error   ;Call print alsa error
    RET                     ;Return to last call

Print_alsa_error:
    ; snd_strerror(int errnum)
    CALL snd_strerror   ;Get ALSA error string
    ADD ESP, 4     ;Clean up stack

    TEST EAX, EAX   ;Check if EAX == EAX
    JZ Done         ;Jump if EAX == 0

    MOV ECX, EAX    ;Set buffer for the error message
    MOV EAX, 4      ;sys_write
    MOV EBX, 1      ;stdout
    MOV EDX, 100    ;Set buffer size = 100
    INT 80H         ;sys_call

Done:
    MOV EAX, 4      ;sys_write
    MOV EBX, 1      ;stdout
    MOV ECX, Newline     ;Print new line
    MOV EDX, 1      ;Set buffer to 1
    INT 80H         ;sys_call
    RET             ;Return to last call

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