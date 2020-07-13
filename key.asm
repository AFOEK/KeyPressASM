SECTION .data   ;deklarasi untuk data/string

Pesan: DB "Untuk memulai tekan tombol enter: "   ;Defind byte pesan
PanjangPesan: Equ $-Pesan   ;ambil panjang pesan (string.lenght)

Dummy: DB "This is Dummy Message for debugging purpose",10
DummyLen:  Equ $-Dummy

MsgMain: DB "Tekan tombol untuk memainkan satu not: (1,2,3,4,5,6,7,8)",10
MsgMainLen: Equ $-MsgMain

MsgError: DB "Error note not found please contact the app developer !!"
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

SECTION .text   ;code section
global _start   ;mulai di label _start / main program
_start:         ;main program in here
    Mov EAX,4   ;sys_write kernel call
    Mov EBX,1   ;stdout trap (standart output) 
    Mov ECX,Pesan   ;Masukkan offset pesan kedalam register ECX
    Mov EDX,PanjangPesan    ;Masukkan panjang pesan kedalam register EDX
    Int 80h     ;call da kernel untuk sys_write stdout

    Mov EAX,3   ;sys_read kernel call
    Mov EBX,0   ;stdin trap (standart input)
    Mov ECX,Enter   ;Masukkan offset/jumlah byte yang akan di baca
    Mov EDX,1   ;Jumlah byte yang dibaca
    Int 80h     ;Call Kernel
    Cmp ECX,13  ;Bandingkan ECX isinya adalah 13 (ASCII code enter)

    ; ;Cara Se Robin;
    ; Mov AH,0x0  ;BIOS readkey trap
    ; Int 0x16    ;BIOS call for keyboard
    ; Mov BL,AL   ;pindah hasil readkey ke register BL
    ; XOR EAX,EAX ;0-kan register EAX (Mov EAX,0)
    ; Mov AL,BL   ;Kembalikan hasil readkey dari register BL ke AL
    ; Cmp ECX,EAX ;Bandingkan ECX dengan EAX

    Jmp EnterKey  ;lompat ke label EnterKey

EnterKey:
    Mov EAX,4
    Mov EBX,1
    Mov ECX,MsgMain
    Mov EDX,MsgMainLen
    Int 80h

    Mov EAX,3   ;sys_read kernel call
    Mov EBX,0   ;stdin trap (standart input)
    Mov ECX,Nada    ;Masukkan offset/jumlah byte yang akan di baca
    Mov EDX,1   ;Jumlah byte yang dibaca
    Int 80h     ;Call Kernel

    Cmp ECX,49
    Je Do_C
    Jne Error

    Cmp ECX,50
    Je Re_D
    Jne Error

    Cmp ECX,51
    Je Mi_E
    Jne Error

    Cmp ECX,52
    Je Fa_F
    Jne Error

    Cmp ECX,53
    Je Sol_G
    Jne Error

    Cmp ECX,54
    Je La_A
    Jne Error

    Cmp ECX,55
    Je Si_B
    Jne Error

    Cmp ECX,56
    Je Do_C.
    Jne Error

Do_C:
    Mov AX,[C]
    Jmp Tone

Re_D:
    Mov AX,[D]
    Jmp Tone

Mi_E:
    Mov AX,[E]
    Jmp Tone

Fa_F:
    Mov AX,[F]
    Jmp Tone

Sol_G:
    Mov AX,[G]
    Jmp Tone

La_A:
    Mov AX,[A]
    Jmp Tone

Si_B:
    Mov AX,[B]
    Jmp Tone

Do_C.:
    Mov AX,[C.]
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