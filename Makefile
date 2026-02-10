restart: restart.c
	gcc -o restart restart.c

asm: test.asm
	nasm -f elf64 test.asm -o test.o
	ld -o asm test.o

