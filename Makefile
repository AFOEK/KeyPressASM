all: run
#/--declare run to all--/#
run: KeyPress
	./KeyPress
.PHONY: all run
#/--set dependency for run a executable and call all to run the executable --/#
#/--source https://stackoverflow.com/questions/15566405/run-executable-from-makefile --/#
KeyPress: key.o
	ld -m elf_i386 -o KeyPress key.o
#/--ld(linux built in linker) -m (linker mode elf32) -o(file output) (object file .o)--/# 
key.o: key.asm
	nasm -f elf -g -F stabs key.asm
#/--nasm(netwide assembly compiler) -f elf64 (format executable linux 64bit) -g (debug info) -F stabs (debug info will be generated in stabs format) (.asm file)--#/
#/--Sauce in Assembly Language Step-by-Step w/Linux page 144-146--/#