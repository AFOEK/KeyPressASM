SECTION .data   ;deklarasi untuk data/string

Pesan: DB "Untuk memulai tekan tombol enter: "   ;Defind byte pesan
PanjangPesan: Equ $-Pesan   ;ambil panjang pesan (string.lenght)

Dummy: DB "This is Dummy Message for debugging purpose",10
DummyLen:  Equ $-Dummy

MsgMain: DB "Tekan tombol untuk memainkan satu not: (1,2,3,4,5,6,7,8)",10
MsgMainLen: Equ $-MsgMain

MsgError: DB "Error note not found please contact the app developer !!",10
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
    c_cc Resb 19      ; control characters

SECTION .text   ;code section
global _start   ;mulai di label _start / main program
_start:         ;main program in here
    Mov EAX,4   ;sys_write kernel call
    Mov EBX,1   ;stdout trap (standart output) 
    Mov ECX,Pesan   ;Masukkan offset pesan kedalam register ECX
    Mov EDX,PanjangPesan    ;Masukkan panjang pesan kedalam register EDX
    syscall     ;call da kernel untuk sys_write stdout

    Mov EAX,3   ;sys_read kernel call
    Mov EBX,0   ;stdin trap (standart input)
    Mov ECX,Enter   ;Masukkan offset/jumlah byte yang akan di baca
    Mov EDX,1   ;Jumlah byte yang dibaca
    syscall     ;Call Kernel
    Cmp ECX,13  ;Bandingkan ECX isinya adalah 13 (ASCII code enter)

    ;Cara Se Robin;
    ; Mov AH,0x0  ;BIOS readkey trap
    ; Int 0x16    ;BIOS call for keyboard
    ; Mov BL,AL   ;pindah hasil readkey ke register BL
    ; XOR EAX,EAX ;0-kan register EAX (Mov EAX,0)
    ; Mov AL,BL   ;Kembalikan hasil readkey dari register BL ke AL
    ; Cmp RAX,EAX ;Bandingkan ECX dengan EAX
    ;This method are restricted by linux kernel, BIOS interrupt cannot be access in x86_64;

    Jmp EnterKey  ;lompat ke label EnterKey

EnterKey:
    Mov EAX,4
    Mov EBX,1
    Mov ECX,MsgMain
    Mov EDX,MsgMainLen
    syscall

    ;This code are from fellow stackoverflow user @fcdt from my own question;
    ;https://stackoverflow.com/questions/62937150/reading-input-from-assembly-on-linux-using-x86-64-sys-call?noredirect=1#comment111297947_62937150;
    ;syscall are same w/ Int 80h (Int 0x80)
    ;https://stackoverflow.com/questions/46087730/what-happens-if-you-use-the-32-bit-int-0x80-linux-abi-in-64-bit-code

    ; Get current settings
    Mov  EAX, 16             ; SYS_ioctl
    Mov  EDI, 0              ; STDIN_FILENO
    Mov  ESI, 0x5401         ; TCGETS
    Mov  RDX, termios
    syscall

    And byte [c_cflag], 0xFD  ; Clear ICANON to disable canonical mode

    ; Write termios structure back
    Mov  EAX, 16             ; SYS_ioctl
    Mov  EDI, 0              ; STDIN_FILENO
    Mov  ESI, 0x5402         ; TCSETS
    Mov  RDX, termios
    syscall

    Mov EAX,0   ;sys_read kernel call
    Mov EBX,0   ;stdin trap (standart input)
    Mov ECX,Nada    ;Masukkan offset/jumlah byte yang akan di baca
    Mov EDX,1   ;Jumlah byte yang dibaca
    syscall     ;Call Kernel

    ; Mov AH,0x0
    ; Int 0x16
    ; XOR ECX,ECX
    ; Mov CL,AL
    ;This method are restricted by linux kernel, BIOS interrupt cannot be access in x86_64;

    ;this section are make to check what key user pressed/enter;
    ;ASCII code for number 1 - 8 are;
    ;49,50,51,52,53,54,55,56;

    Cmp RAX,49
    Je Do_C

    Cmp RAX,50
    Je Re_D

    Cmp RAX,51
    Je Mi_E

    Cmp RAX,52
    Je Fa_F

    Cmp RAX,53
    Je Sol_G

    Cmp RAX,54
    Je La_A

    Cmp RAX,55
    Je Si_B

    Cmp RAX,56
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
    syscall
Tone:
    
    Jmp Exit
Exit:    
    Mov EAX,1   ;keluar dari sys_call
    Mov EBX,0   ;Return 0 (Avoid Segmentation fault (core dumped))
    syscall     ;call da kernel (Prosedur penting agar code dapat keluar secara baik)