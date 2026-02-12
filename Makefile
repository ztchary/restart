restart: restart.asm
	nasm -f elf64 restart.asm -o restart.o
	ld -o restart restart.o

