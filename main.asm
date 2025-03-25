SECTION .data   ;Declare variables

Message: DB "Press (or hold) key to play note (A - K)", 10
Message_len: EQU $-Message

Debug_Msg: DB "OK !", 10
Debug_Msg_len: EQU $-Debug_Msg

Message_err: DB "Error !",10
Message_err_len: EQU $Message_err_len

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

timespec:
    tv_sec: DD 0    ; Seconds
    tv_nsec: DD 10000000 ;Nano seconds (10 ms)

SECTION .bss    ;Uninitialized data section / memory reserve
Input_buff RESB 1   ; Buffer for keyboard input
Audio_fd RESB 1 ;File descriptor for audio file
Phase_rad RESB 1    ;Current phase increment (Rad/sample)
Last_key RESB 1 ;Store last key value (0 if None)
Phase_acc Resb 1    ;Phase accumulator (64 bit precision)


SECTION .text   ;Code section
global _start   ;Set starting point
_start:         ;main()
    MOV EAX, 4  ;Call sys_write
    MOV EBX, 1  ;stdout
    MOV ECX, Message    ;message content
    MOV EDX, Message_len ;message_len
    INT 80h ;System interupt (sys_call)

    MOV EAX, 5  ;Call sys_open
    MOV EBX, Audio_dev_path ;Set audio path
    MOV ECX, 1  ; O_WRONLY (Write only mode)
    MOV EDX, 0  ; No mode
    INT 80h ;sys_call

    CMP EAX, 0  ;Compare EAX (sys_open return value) == 0
    JL exit ;Jump if EAX < 0 else continue
    MOV [Audio_fd], EAX ; Set file descriptor memory value to EAX
    ;;Set non block stdin (default; stdin always terminate if )
    MOV EAX, 55 ;Call sys_fcntl
    MOV EBX, 0  ;stdin
    MOV ECX, 3  ;F_GETFL (get current flag)
    INT 80h     ;sys_call

    OR EAX, 2048    ;set O_NONBLOCK flag value
    MOV EBX, 0      ;stdin
    MOV ECX, 4      ;F_SETFL (set new flag)
    MOV EDX, EAX    ;MOV EAX (New flag value {OE EAX, 2048} to EDX)
    MOV EAX, 55     ;sys_fnctl
    INT 80h         ;sys_call

main_loop:
    ;Check keyboard input if no continue
    CALL check_keyboard

    CMP byte [Last_key], 0  ;check if last key (memory value) == 0
    JE short_pause          ;Jump if [Last_key] == 0

    CALL play_note_segment  ;play current note
    JMP main_loop   ;loop again