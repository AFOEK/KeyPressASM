;==================================PreNote======================================;
;This some info or term are used in Linux/UNIX;                                 |
;STDIN (Standart Input), STDOUT (Standart Output), STDERR (Standart Error);     |
;Termios C Struct are in "/usr/include/asm-generic/termios.h";                  |
;-------------------------------------------------------------------------------;
; struct termio {                                                               |
; 	unsigned short c_iflag;		/* input mode flags */                          |
; 	unsigned short c_oflag;		/* output mode flags */                         |
; 	unsigned short c_cflag;		/* control mode flags */                        |
; 	unsigned short c_lflag;		/* local mode flags */                          |
; 	unsigned char c_line;		/* line discipline */                           |
; 	unsigned char c_cc[NCC];	/* control characters */                        |
; }                                                                             |
;-------------------------------------------------------------------------------;
;For read and write are in "usr/include/unistd.h";                              |
;-------------------------------------------------------------------------------;
;extern ssize_t read (int __fd, void *__buf, size_t __nbytes) __wur;            |
;extern ssize_t write (int __fd, const void *__buf, size_t __n) __wur;          |
;-------------------------------------------------------------------------------;
;ReadMe.txt for more citation, book reference, and link                         |
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

C: DW 4560
D: DW 4063
E: DW 3619
F: DW 3416
G: DW 3043
A: DW 2711
B: DW 2415
C.: DW 2280

SECTION .bss    ;deklarasi untuk variable yang belum terdefinisi

Enter: Resb 1   ;Pesan 1 byte untuk Enter
Nada: Resb 1
termios: 
    c_iflag Resd 1    ; input mode flags
    c_oflag Resd 1    ; output mode flags
    c_cflag Resd 1    ; control mode flags
    c_lflag Resd 1    ; local mode flags
    c_line Resb 1     ; line discipline
    c_cc Resb 64      ; control characters

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
    Cmp byte [Enter],0x13  ;Bandingkan isi buffer adalah 13 (ASCII code enter)

    ;Cara Se Robin;
    ; Mov AH,0x0  ;BIOS readkey trap
    ; Int 0x16    ;BIOS call for keyboard
    ; Mov BL,AL   ;pindah hasil readkey ke register BL
    ; XOR EAX,EAX ;0-kan register EAX (Mov EAX,0)
    ; Mov AL,BL   ;Kembalikan hasil readkey dari register BL ke AL
    ; Cmp ECX,EAXS ;Bandingkan ECX dengan EAX
    ;This method are restricted by linux kernel, BIOS interrupt cannot be access in x86_64;

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
    Mov EAX, 54             ; SYS_ioctl
    Mov EBX, 0              ; STDIN_FILENO
    Mov ECX, 0x5401         ; TCGETS
    Mov EDX, termios
    Int 80h

    ;And byte [c_lflag], 0xFD  ; Clear ICANON to disable canonical mode
    ;This have 2 varian choose uncomment if one of this doesn't work;
    And dword [c_lflag], 0xFFFFFFFD  ; Clear ICANON to disable canonical mode

    ; Write termios structure back
    Mov EAX, 54             ; SYS_ioctl
    Mov EBX, 0              ; STDIN_FILENO
    Mov ECX, 0x5402         ; TCSETS
    Mov EDX, termios
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

    Cmp byte [ECX],1
    Je Do_C

    Cmp byte [ECX],2
    Je Re_D

    Cmp byte [ECX],3
    Je Mi_E

    Cmp byte [ECX],4
    Je Fa_F

    Cmp byte [ECX],5
    Je Sol_G

    Cmp byte [ECX],6
    Je La_A

    Cmp byte [ECX],7
    Je Si_B

    Cmp byte [ECX],8
    Je Do_C.
    Jmp Error

Do_C:
    Mov AX,word [C]
    Jmp Tone

Re_D:
    Mov AX,word [D]
    Jmp Tone

Mi_E:
    Mov AX,word [E]
    Jmp Tone

Fa_F:
    Mov AX,word [F]
    Jmp Tone

Sol_G:
    Mov AX,word [G]
    Jmp Tone

La_A:
    Mov AX,word [A]
    Jmp Tone

Si_B:
    Mov AX,word [B]
    Jmp Tone

Do_C.:
    Mov AX,word [C.]
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