bits 64
default rel

O_RDONLY EQU 2

SYS_READ  EQU 0
SYS_WRITE EQU 1
SYS_OPEN  EQU 2
SYS_CLOSE EQU 3
SYS_STAT  EQU 4
SYS_BRK   EQU 12

section .text

open_file:
	mov rdi, rax
	mov rax, O_RDONLY
	xor rsi, rsi
	xor rdx, rdx
	syscall
	ret

close_file:
	mov rdi, rax
	mov rax, SYS_CLOSE
	syscall
	ret

stat_file:
	mov rdi, rax
	mov rax, SYS_STAT
	mov rsi, statbuf
	syscall
	ret

strlen:
	mov rdi, rax
_sl0:
	cmp byte [rax], 0
	je _sl1
	add rax, 1
	jmp _sl0
_sl1:
	sub rax, rdi
	ret

strcat:
_sc0:
	cmp byte [rax], 0
	je _sc1
	add rax, 1
	jmp _sc0
_sc1:
	mov sil, [rdi]
	mov [rax], sil
	cmp byte [rdi], 0
	je _sc2
	add rax, 1
	add rdi, 1
	jmp _sc1
_sc2:
	ret

reserve:
	push rbp
	mov rbp, rsp
	sub rsp, 16

	; amount to reserve
	mov [rbp - 8], rax

	; brk: get old top
	mov rax, SYS_BRK
	xor rdi, rdi
	syscall

	; old top
	mov [rbp - 16], rax

	; brk: set new top
	mov rax, SYS_BRK
	mov rdi, [rbp - 16]
	add rdi, [rbp - 8]
	syscall

	; old top = new reserved region
	mov rax, [rbp - 16]

	mov rsp, rbp
	pop rbp
	ret

global _start
_start:

	mov rax, [rsp]
	mov [argc], rax
	mov [argv], rsp
	add [argv], 8

	mov rbp, rsp
	sub rsp, 16

	cmp [argc], 2
	jne err_args

	; reserve 4096 bytes for path stuff
	mov rax, 4096
	call reserve

	; executable path
	mov [basepath], rax
	mov rdi, procpath
	call strcat
	mov rax, [basepath]
	mov rbx, [argv]
	add rbx, 8
	mov rdi, [rbx]
	call strcat
	; result "/proc/12345\0"

	mov rax, [basepath]
	call strlen

	mov rdx, rax

	mov rax, 1
	mov rdi, 1
	mov rsi, [basepath]
	syscall

	mov rax, [basepath]
	call stat_file

	; if stat returns negative, it probably doesn't exist
	cmp rax, 0
	jne err_nsp

	mov rax, [st_uid]
	mov [rbp - 16], rax

	mov rax, [basepath]
	call strlen
	add rax, [basepath]
	add rax, 1
	mov [cwdpath], rax 
	mov rdi, [basepath]
	call strcat
	mov rax, [cwdpath]
	mov rdi, [scwd]
	call strcat

	mov rax, [scwd]
	call strlen
	mov rdx, rax

	mov rax, 1
	mov rdi, 1
	mov rsi, [scwd]
	syscall


exit:
	mov rax, 60
	syscall

err_nsp:
	mov rax, 1
	mov rdi, 1
	mov rsi, err_msg_nsp
	mov rdx, err_msg_nsp_len
	syscall
	mov rdi, 1
	jmp exit

err_args:
	mov rax, 1
	mov rdi, 1
	mov rsi, err_msg_args
	mov rdx, err_msg_args_len
	syscall
	mov rdi, 1
	jmp exit

section .data
	procpath db "/proc/", 0
	scwd db "/cwd", 0
	sexe db "/exe", 0
	scmdline db "/cmdline", 0
	senviron db "/environ", 0

	err_msg_nsp db "No such process.", 10
	err_msg_nsp_len equ $ - err_msg_nsp

	err_msg_args db "Wrong arguments.", 10
	err_msg_args_len equ $ - err_msg_args

section .bss

	basepath resq 1;
	cwdpath resq 1;
	exepath resq 1;
	cmdlinepath resq 1;
	environpath resq 1;

	argc resq 1;
	argv resq 1;
	envp resq 1;

	statbuf:
    st_dev resb 8;
    st_ino resb 8;
    st_nlink resb 8;

    st_mode resb 4;
    st_uid resb 4;
    st_gid resb 4;
    _pad0 resb 4;
    st_rdev resb 8;
    st_size resb 8;
    st_blksize resb 8;
    st_blocks resb 8;

    st_atime resb 8;
    st_atime_nsec resb 8;
    st_mtime resb 8;
    st_mtime_nsec resb 8;
    st_ctime resb 8;
    st_ctime_nsec resb 8;
    _unused resb 24;

