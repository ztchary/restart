CC=cc
CFLAGS=-Wall -Werror

restart: restart.asm
	nasm -f elf64 restart.asm -o restart.o
	ld -o restart restart.o

restartc: restart.c
	$(CC) $(CFLAGS) -o restartc restart.c

install:
	install -m 755 restart /usr/bin

