;==================================PreNote======================================;
;This some info or term are used in Linux/UNIX;                                 |
;STDIN (Standart Input), STDOUT (Standart Output), STDERR (Standart Error);     |
;Termios C Struct are in "/usr/include/asm-generic/termios.h";                  |
;or for more specific in "/usr/include/bits/termios-struct.h";                  |
;-----------------------/usr/include/asm-generic/termios.h----------------------;
; struct termio {                                                               |
; 	unsigned short c_iflag;		/* input mode flags */                          |
; 	unsigned short c_oflag;		/* output mode flags */                         |
; 	unsigned short c_cflag;		/* control mode flags */                        |
; 	unsigned short c_lflag;		/* local mode flags */                          |
; 	unsigned char c_line;		/* line discipline */                           |
; 	unsigned char c_cc[NCC];	/* control characters */                        |
; }                                                                             |
;----------------------/usr/include/bits/termios-struct.h-----------------------;
; struct termios                                                                |
;   {                                                                           |
;     tcflag_t c_iflag;		/* input mode flags */                              |
;     tcflag_t c_oflag;		/* output mode flags */                             |
;     tcflag_t c_cflag;		/* control mode flags */                            |
;     tcflag_t c_lflag;		/* local mode flags */                              |
;     cc_t c_line;			/* line discipline */                               |
;     cc_t c_cc[NCCS];		/* control characters */                            |
;     speed_t c_ispeed;		/* input speed */                                   |
;     speed_t c_ospeed;		/* output speed */                                  |
;   }                                                                           |
;-------------------------------------------------------------------------------;
;For read and write are in "usr/include/unistd.h";                              |
;-------------------------------------------------------------------------------;
;extern ssize_t read (int __fd, void *__buf, size_t __nbytes) __wur;            |
;extern ssize_t write (int __fd, const void *__buf, size_t __n) __wur;          |
;-------------------------------------------------------------------------------;
;ReadMe.txt for more citation, book reference, and link                         |
;-------------------------------------------------------------------------------|
;++++++++++++++++++++++++++ASCII C0de Reference+++++++++++++++++++++++++++++++++|
;|---HEX---|---Character---|------Description-------|---------------------------|
;    0x0   |      NUL      |         NULL           |
;    0x1   |      SOH      |   Start of Header      |
;    0x2   |      STX      |    Start of Text       |
;    0x3   |      ETX      |     End of Text        |
;    0x4   |      EOT      |  End of Trasnmission   |
;    0x5   |      ENQ      |       Enquiry          |
;    0x6   |      ACK      |     Acknowledge        |
;    0x7   |      BEL      |        Bell            |
;    0x8   |      BS       |      Backspace         |
;    0x9   |      HT       |    Horizontal Tab      |
;    0x10  |      LF       |      Line Feed         |
;    0x11  |      VT       |     Vertical Tab       |
;    0x12  |      FF       |      Form Feed         |
;    0x13  |      CR       |   Carriage Return      |
;    0x14  |      SO       |      Shift Out         |
;    0x15  |      SI       |      Shift In          |
;    0x16  |      DLE      |   Data Link Escape     |
;    0x17  |      DC1      |   Device Control 1     |
;    0x18  |      DC2      |   Device Control 2     |
;    0x19  |      DC3      |   Device Control 3     |
;    0x20  |      DC4      |   Device Control 4     |
;    0x21  |      NAK      | Negative Acknowledge   |
;    0x22  |      SYN      |     Synchronize        |
;    0x23  |      ETB      | End Transmission Block |
;    0x24  |      CAN      |        Cancel          |
;    0x25  |      EM       |     End Of Medium      |
;    0x26  |      SUB      |      Substitute        |
;    0x27  |      ESC      |        Escape          |
;    0x28  |      FS       |     File Seperator     |
;    0x29  |      GS       |    Group Seperator     |
;    0x30  |      RS       |    Record Seperator    |
;    0x31  |      US       |     Unit Seperator     |
;    0x48  |      0        |           0            |
;    ....  |     ...       |          ...           |
;    0x57  |      9        |           9            |
;    0x65  |      A        |           A            |
;    ....  |     ...       |          ...           |
;    0x90  |      Z        |           Z            |
;    0x97  |      a        |           a            |
;    ....  |     ...       |          ...           |
;    0x122 |      z        |           z            |
;    0x127 |     DEL       |        Delete          |
;+++++++++++++++++++++++++++++EndASCIIC0deReference+++++++++++++++++++++++++++++;
; Arch/ABI    Instruction           System  Ret  Ret  Error    Notes
;                                   call #  val  val2
; ───────────────────────────────────────────────────────────────────
; alpha       callsys               v0      v0   a4   a3       1, 6
; arc         trap0                 r8      r0   -    -
; arm/OABI    swi NR                -       a1   -    -        2
; arm/EABI    swi 0x0               r7      r0   r1   -
; arm64       svc #0                x8      x0   x1   -
; blackfin    excpt 0x0             P0      R0   -    -
; i386        int $0x80             eax     eax  edx  -
; ia64        break 0x100000        r15     r8   r9   r10      1, 6
; m68k        trap #0               d0      d0   -    -
; microblaze  brki r14,8            r12     r3   -    -
; mips        syscall               v0      v0   v1   a3       1, 6
; nios2       trap                  r2      r2   -    r7
; parisc      ble 0x100(%sr2, %r0)  r20     r28  -    -
; powerpc     sc                    r0      r3   -    r0       1
; powerpc64   sc                    r0      r3   -    cr0.SO   1
; riscv       ecall                 a7      a0   a1   -
; s390        svc 0                 r1      r2   r3   -        3
; s390x       svc 0                 r1      r2   r3   -        3
; superh      trap #0x17            r3      r0   r1   -        4, 6
; sparc/32    t 0x10                g1      o0   o1   psr/csr  1, 6
; sparc/64    t 0x6d                g1      o0   o1   psr/csr  1, 6
; tile        swint1                R10     R00  -    R01      1
; x86-64      syscall               rax     rax  rdx  -        5
; x32         syscall               rax     rax  rdx  -        5
; xtensa      syscall               a2      a2   -    -
;-------------------------------------------------------------------------------;
; Arch/ABI      arg1  arg2  arg3  arg4  arg5  arg6  arg7  Notes
; ──────────────────────────────────────────────────────────────
; alpha         a0    a1    a2    a3    a4    a5    -
; arc           r0    r1    r2    r3    r4    r5    -
; arm/OABI      a1    a2    a3    a4    v1    v2    v3
; arm/EABI      r0    r1    r2    r3    r4    r5    r6
; arm64         x0    x1    x2    x3    x4    x5    -
; blackfin      R0    R1    R2    R3    R4    R5    -
; i386          ebx   ecx   edx   esi   edi   ebp   -
; ia64          out0  out1  out2  out3  out4  out5  -
; m68k          d1    d2    d3    d4    d5    a0    -
; microblaze    r5    r6    r7    r8    r9    r10   -
; mips/o32      a0    a1    a2    a3    -     -     -     1
; mips/n32,64   a0    a1    a2    a3    a4    a5    -
; nios2         r4    r5    r6    r7    r8    r9    -
; parisc        r26   r25   r24   r23   r22   r21   -
; powerpc       r3    r4    r5    r6    r7    r8    r9
; powerpc64     r3    r4    r5    r6    r7    r8    -
; riscv         a0    a1    a2    a3    a4    a5    -
; s390          r2    r3    r4    r5    r6    r7    -
; s390x         r2    r3    r4    r5    r6    r7    -
; superh        r4    r5    r6    r7    r0    r1    r2
; sparc/32      o0    o1    o2    o3    o4    o5    -
; sparc/64      o0    o1    o2    o3    o4    o5    -
; tile          R00   R01   R02   R03   R04   R05   -
; x86-64        rdi   rsi   rdx   r10   r8    r9    -
; x32           rdi   rsi   rdx   r10   r8    r9    -
; xtensa        a6    a3    a4    a5    a8    a9    -
;-------------------------------------------------------------------------------;
;===============================EndPreNote======================================;

SECTION .data   ;deklarasi untuk data/string

Pesan: DB "Untuk memulai tekan tombol enter: "   ;Defind byte pesan
PanjangPesan: Equ $-Pesan   ;ambil panjang pesan (string.lenght)

Dummy: DB "This is Dummy Message for debugging purpose",10
DummyLen:  Equ $-Dummy

MsgMain: DB "Tekan tombol untuk memainkan satu not: (1,2,3,4,5,6,7,8)",10   ;\n
MsgMainLen: Equ $-MsgMain

MsgError: DB 10,"Error note not found please contact the app developer !!",10
MsgErrorLen: Equ $-MsgError

;Is not usefull because the frequency already pre-scaled;
; C: DW 4560
; D: DW 4063
; E: DW 3619
; F: DW 3416
; G: DW 3043
; A: DW 2711
; B: DW 2415
; C.: DW 2280
;Below are frequency table which already converted to radians and divided by 8000;
;Thanks u/FUZxxl for the completed tutorial and insight;

FreqTable:
    DQ 2.0548023848490921e-1    ;C
    DQ 2.3064376937686967e-1    ;D
    DQ 2.5888887780455583e-1    ;E
    DQ 2.7428321157402019e-1    ;F
    DQ 3.0787249548024787e-1    ;G
    DQ 3.4557519189487729e-1    ;A
    DQ 3.8789503773922857e-1    ;B
    DQ 4.1096047696981880e-1    ;C'

path: DB '/dev/snd/note'
pathLen: Equ $-path

SECTION .bss    ;deklarasi untuk variable yang belum terdefinisi

Enter: Resb 1   ;Pesan 1 byte untuk Enter
Nada: Resb 1    ;Reserve 1 byte
termios: 
    c_iflag Resd 1    ; input mode flags
    c_oflag Resd 1    ; output mode flags
    c_cflag Resd 1    ; control mode flags
    c_lflag Resd 1    ; local mode flags
    c_line Resb 1     ; line discipline
    c_cc Resb 64      ; control characters
WriteBuffer: Resd 2024  ;Reserve 2KiB

SECTION .text   ;code section
global _start   ;mulai di label _start / main program
_start:         ;main program in here
    Mov EAX,4   ;sys_write kernel call
    Mov EBX,1   ;stdout trap (standart output) 
    Mov ECX,Pesan   ;Masukkan offset pesan kedalam register ECX
    Mov EDX,PanjangPesan    ;Masukkan panjang pesan kedalam register EDX
    Int 80h    ;call da kernel untuk sys_write stdout

    Mov EAX,3   ;sys_read kernel call
    Mov EBX,0   ;stdin trap (standart input)
    Mov ECX,Enter   ;Masukkan jumlah buffer yang akan ditampung, Enter = ECX
    Mov EDX,1   ;Jumlah byte yang dibaca
    Int 80h    ;Call Kernel

    Cmp EAX,0   ;Check return value of sys_read 0 (0 Means EOF [End of Line])
    Je _start   ;if equal jump to start again
    Cmp byte [Enter],'0x13'  ;Bandingkan isi buffer adalah 13 (ASCII code enter)

    ;Cara Se Robin;
    ; Mov AH,0x0  ;BIOS readkey trap
    ; Int 0x16    ;BIOS call for keyboard
    ; Mov BL,AL   ;pindah hasil readkey ke register BL
    ; XOR EAX,EAX ;0-kan register EAX (Mov EAX,0)
    ; Mov AL,BL   ;Kembalikan hasil readkey dari register BL ke AL
    ; Cmp ECX,EAXS ;Bandingkan ECX dengan EAX
    ;This method are restricted by linux kernel, BIOS interrupt cannot be access in x86_32;

    Jmp EnterKey  ;lompat ke label EnterKey

EnterKey:
    Mov EAX,4
    Mov EBX,1
    Mov ECX,MsgMain
    Mov EDX,MsgMainLen
    Int 80h

    ;This code are from fellow stackoverflow user @fcdt from my own question;
    ;https://stackoverflow.com/questions/62937150/reading-input-from-assembly-on-linux-using-x86-64-sys-call?noredirect=1#comment111297947_62937150;
    ;syscall are for x86_64 instruction set;
    ;Int 80h/int 0x80 for x86_32 instruction set;
    ;https://stackoverflow.com/questions/46087730/what-happens-if-you-use-the-32-bit-int-0x80-linux-abi-in-64-bit-code
    ;refined by @Martin Rosenau on stackoverflow;
    ;https://stackoverflow.com/questions/63027222/linux-temios-non-canonical-sys-call-getch-doesnt-work/63027767#63027767;

    ;Get current settings
    Mov EAX,54             ; SYS_ioctl
    Mov EBX,0              ; STDIN_FILENO
    Mov ECX,0x5401         ; TCGETS
    Mov EDX,termios
    Int 80h

    ;And byte [c_lflag], 0xFD  ; Clear ICANON to disable canonical mode
    ;This have 2 varian choose uncomment if one of this doesn't work;
    And dword [c_lflag], 0xFFFFFFFD  ; Clear ICANON to disable canonical mode

    ; Write termios structure back
    Mov EAX,54             ; SYS_ioctl
    Mov EBX,0              ; STDIN_FILENO
    Mov ECX,0x5402         ; TCSETS
    Mov EDX,termios
    Int 80h

    Mov EAX,3   ;sys_read kernel call
    Mov EBX,0   ;stdin trap (standart input)
    Mov ECX,Nada    ;Masukkan jumlah buffer yang akan ditampung, Enter = ECX
    Mov EDX,1   ;Jumlah byte yang dibaca
    Int 80h     ;Call Kernel

    Cmp EAX,0
    Je _start

    ; Mov AH,0x0
    ; Int 0x16
    ; XOR ECX,ECX
    ; Mov CL,AL
    ;This method are restricted by linux kernel, BIOS interrupt cannot be access in x86_64;

    ;this section are make to check what key user pressed/enter;
    ;ASCII code for number 1 - 8 are;
    ;49,50,51,52,53,54,55,56;
    ;Just for debugging purpose;
    ; Mov EAX,4
    ; Mov EBX,1
    ; Mov ECX,Nada
    ; Mov EDX,1
    ; Int 80h

    Cmp byte [ECX],'1'
    Je Do_C

    Cmp byte [ECX],'2'
    Je Re_D

    Cmp byte [ECX],'3'
    Je Mi_E

    Cmp byte [ECX],'4'
    Je Fa_F

    Cmp byte [ECX],'5'
    Je Sol_G

    Cmp byte [ECX],'6'
    Je La_A

    Cmp byte [ECX],'7'
    Je Si_B

    Cmp byte [ECX],'8'
    Je Do_C.
    Jmp Error

Open:
    Mov EAX,5
    Mov EBX,path
    Mov ECX,2
    Int 80h
Do_C:
    
    Jmp Tone

Re_D:
    
    Jmp Tone

Mi_E:
    
    Jmp Tone

Fa_F:
    
    Jmp Tone

Sol_G:
    
    Jmp Tone

La_A:
    
    Jmp Tone

Si_B:
    
    Jmp Tone

Do_C.:
    
    Jmp Tone

Error:
    Mov EAX,4
    Mov EBX,1
    Mov ECX,MsgError
    Mov EDX,MsgErrorLen
    Int 80h
Tone:
    
    Jmp Exit
Exit:    
    Mov EAX,1   ;keluar dari sys_call
    Mov EBX,0   ;Return 0 (Avoid Segmentation fault (core dumped))
    Int 80h     ;call da kernel (Prosedur penting agar code dapat keluar secara baik)