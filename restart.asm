bits 64
default rel

BLOCK_SIZE equ 1024

O_RDONLY  equ 0

SYS_READ  equ 0
SYS_WRITE equ 1
SYS_OPEN  equ 2
SYS_CLOSE equ 3
SYS_STAT  equ 4
SYS_BRK   equ 12
SYS_SLEEP equ 35
SYS_FORK  equ 57
SYS_EXECV equ 59
SYS_EXIT  equ 60
SYS_KILL  equ 62
SYS_DENTS equ 78
SYS_CHDIR equ 80
SYS_RLINK equ 89
SYS_GUID  equ 102
SYS_SUID  equ 105
SYS_SSID  equ 112

STDIN_FD  equ 0
STDOUT_FD equ 1
STDERR_FD equ 2

SIG_INT   equ 2

section .text


strmov:
.a0:
	mov al, [rsi]
	mov [rdi], al
	cmp al, 0
	je .b0

	inc rdi
	inc rsi

	jmp .a0

.b0:
	ret


strend:
	jmp .c0
.a0:
	inc rdi
.c0:
	cmp byte [rdi], 0
	jne .a0
	mov rax, rdi
	ret


strcat:
	push rsi
	call strend
	mov rdi, rax
	pop rsi
	call strmov
	ret


strcmp:
	jmp .c0

.a0:
	inc rdi
	inc rsi

.c0:
	mov al, [rdi]
	cmp al, [rsi]
	jne .b0
	cmp al, 0
	jne .a0

	mov rax, 1
	ret

.b0:
	mov rax, 0
	ret


atoi:
	xor rax, rax

.a0:
	mul rax, 10
	movzx rsi, byte [rdi]
	sub rsi, '0'
	add rax, rsi
	inc rdi

	cmp byte [rdi], 0
	jne .a0
	ret


reserve_block:
	mov rax, SYS_BRK
	xor rdi, rdi
	syscall

	mov rdi, rax
	add rdi, BLOCK_SIZE
	mov rax, SYS_BRK
	syscall

	sub rax, BLOCK_SIZE
	ret


readlink:
	push rdi
	call reserve_block
	pop rdi

	mov rsi, rax
	mov rax, SYS_RLINK
	mov rdx, BLOCK_SIZE
	syscall

	mov byte [rsi + rax], 0

	mov rax, rsi
	ret


read_file:
	push rbp
	mov rbp, rsp
	sub rsp, 24

	; -8  : file descriptor
	; -16 : data ptr
	; -24 : bytes read

	mov qword [rbp - 24], 0

	mov rax, SYS_OPEN
	mov rsi, O_RDONLY
	xor rdx, rdx
	syscall

	mov [rbp - 8], rax

	call reserve_block
	mov [rbp - 16], rax

.a0:
	mov rsi, rax
	mov rax, SYS_READ
	mov rdi, [rbp - 8]
	mov rdx, BLOCK_SIZE
	syscall

	add [rbp - 24], rax

	cmp rax, BLOCK_SIZE
	jne .b0

	call reserve_block
	jmp .a0

.b0:
	mov rax, SYS_CLOSE
	syscall

	mov rax, [rbp - 16]
	mov rdx, [rbp - 24]

	mov rsp, rbp
	pop rbp
	ret


make_ptrptr:
	push rbp
	mov rbp, rsp
	sub rsp, 48

	; - 8 : in ptr
	; -16 : in len
	; -24 : in off
	; -32 : out ptr
	; -40 : out len
	; -48 : out off

	mov [rbp - 8], rdi
	mov [rbp - 16], rsi
	mov qword [rbp - 24], 0

	call reserve_block
	mov [rbp - 32], rax
	mov qword [rbp - 40], BLOCK_SIZE
	mov qword [rbp - 48], 0

.a0:
	mov rax, [rbp - 24]
	cmp rax, [rbp - 16]
	jge .b0

	add rax, [rbp - 8]
	mov rbx, [rbp - 32]
	mov rcx, [rbp - 48]

	mov [rbx + rcx], rax

	add rcx, 8
	mov [rbp - 48], rcx
	cmp rcx, [rbp - 40]

	jl .b1

	call reserve_block

	add qword [rbp - 40], BLOCK_SIZE

.b1:
	mov rax, [rbp - 32]
	mov rbx, [rbp - 48]
	mov qword [rax + rbx], 0

	mov rax, [rbp - 8]
	mov rbx, [rbp - 24]
	jmp .c0

.a1:
	inc rbx
.c0:
	cmp byte [rax + rbx], 0
	jne .a1

	inc rbx
	mov [rbp - 24], rbx

	jmp .a0
.b0:

	mov rax, [rbp - 32]

	mov rsp, rbp
	pop rbp

	ret


pgrep:

	; -  8 : pname
	; - 16 : dir fd
	; - 24 : dirent ptr
	; - 32 : dirent end ptr
	; - 64 : file buf
	; -320 : dirent buf

	push rbp
	mov rbp, rsp
	sub rsp, 320

	mov [rbp - 8], rdi

	mov rax, SYS_OPEN
	mov rdi, procpath
	mov rsi, O_RDONLY
	mov rdx, 0
	syscall

	mov [rbp - 16], rax

.a0:
	mov rax, SYS_DENTS
	mov rdi, [rbp - 16]
	lea rsi, [rbp - 320]
	mov rdx, 256
	syscall

	cmp rax, 0
	jle .b1

	mov [rbp - 24], rsi
	add rsi, rax
	mov [rbp - 32], rsi

	jmp .c1
.a1:
	mov rdi, [rbp - 24]
	add rdi, 18

	mov al, byte [rdi]
	cmp al, '0'
	jl .b0
	cmp al, '9'
	jg .b0

	lea rdi, [rbp - 64]
	mov rsi, procpath
	call strmov

	lea rdi, [rbp - 64]
	mov rsi, [rbp - 24]
	add rsi, 18
	call strcat

	lea rdi, [rbp - 64]
	mov rsi, scomm
	call strcat

	mov rax, SYS_OPEN
	lea rdi, [rbp - 64]
	mov rsi, O_RDONLY
	mov rdx, 0
	syscall

	mov rdi, rax
	mov rax, SYS_READ
	lea rsi, [rbp - 64]
	mov rdx, 32
	syscall

	mov byte [rbp + rax - 65], 0

	mov rax, SYS_CLOSE
	syscall

	lea rdi, [rbp - 64]
	mov rsi, [rbp - 8]
	call strcmp

	cmp rax, 0
	je .b0

	mov rax, SYS_CLOSE
	mov rdi, [rbp - 16]
	syscall

	call reserve_block

	push rax

	mov rdi, rax
	mov rsi, [rbp - 24]
	add rsi, 18
	call strmov

	pop rax

	mov rsp, rbp
	pop rbp
	ret

.b0:
	mov rdi, [rbp - 24]
	movzx rax, word [rdi + 16]
	add [rbp - 24], rax

.c1:
	mov rax, [rbp - 24]
	cmp rax, [rbp - 32]
	jl .a1
	jmp .a0

.b1:
	mov rax, SYS_CLOSE
	mov rdi, [rbp - 16]
	syscall

	mov rax, 0

	mov rsp, rbp
	pop rbp
	ret


global _start
_start:
	; +16 : argv[1] (pname)
	; + 8 : argv[0] (exe)
	;   0 : argc
	; - 8 : basepath
	; -16 : append ptr
	; -24 : uid
	; -32 : cwd
	; -40 : exe
	; -48 : cmdline
	; -56 : environ
	; -64 : pid but int
	; -72 : pid but str

	mov rbp, rsp
	sub rsp, 72

	cmp [rbp], 2
	jne .err_args

	mov rdi, [rbp + 16]
	call pgrep

	cmp rax, 0
	je .err_nsp

	mov [rbp - 72], rax

	; path stuff
	; /proc/1234

	mov rdi, [rbp - 72]
	call atoi
	mov [rbp - 64], rax

	call reserve_block
	mov [rbp - 8], rax

	mov rdi, [rbp - 8]
	mov rsi, [rbp - 72]
	mov rsi, procpath
	call strmov
	mov rdi, [rbp - 8]
	mov rsi, [rbp - 72]
	call strcat

	; points to the end of the base path
	mov rdi, [rbp - 8]
	call strend
	mov [rbp - 16], rax

	mov rax, SYS_STAT
	mov rdi, [rbp - 8]
	mov rsi, statbuf
	syscall

	; if stat returns negative, it probably doesn't exist
	cmp rax, 0
	jne .err_nsp

	; save uid
	mov eax, [st_uid]
	mov [rbp - 24], rax

	mov rax, SYS_GUID
	syscall

	; ensure we have permission
	cmp rax, 0
	je .root_or_matching

	cmp rax, [rbp - 24]
	je .root_or_matching

	jmp .err_perm

.root_or_matching:

	; get cwd of process
	mov rdi, [rbp - 16]
	mov rsi, scwd
	call strmov

	mov rdi, [rbp - 8]
	call readlink

	mov [rbp - 32], rax

	; get exe of process
	mov rdi, [rbp - 16]
	mov rsi, sexe
	call strmov

	mov rdi, [rbp - 8]
	call readlink

	mov [rbp - 40], rax

	; get cmdline of process
	mov rdi, [rbp - 16]
	mov rsi, scmdline
	call strmov

	mov rdi, [rbp - 8]
	call read_file

	mov rdi, rax
	mov rsi, rdx
	call make_ptrptr
	mov [rbp - 48], rax

	; get environ of process
	mov rdi, [rbp - 16]
	mov rsi, senviron
	call strmov

	mov rdi, [rbp - 8]
	call read_file

	mov rdi, rax
	mov rsi, rdx
	call make_ptrptr
	mov [rbp - 56], rax

	; kill
	mov rax, SYS_KILL
	mov rdi, [rbp - 64]
	mov rsi, SIG_INT
	syscall

	; wait for it to die
.waiting:
	; check process
	mov rax, SYS_KILL
	mov rdi, [rbp - 64]
	mov rsi, 0
	syscall

	cmp rax, 0
	jne .done_waiting

	; wait
	mov rax, SYS_SLEEP
	mov rdi, timespec
	mov rsi, 0
	syscall
	jmp .waiting
.done_waiting:

	; fork
	mov rax, SYS_FORK
	syscall

	cmp rax, 0
	jne .exit0

	; setuid
	mov rax, SYS_SUID
	mov rdi, [rbp - 24]
	syscall

	; setsid
	mov rax, SYS_SSID
	syscall

	; close stdout/stderr
	mov rax, SYS_CLOSE
	mov rdi, STDOUT_FD
	syscall

	mov rax, SYS_CLOSE
	mov rdi, STDERR_FD
	syscall

	; chdir
	mov rax, SYS_CHDIR
	mov rdi, [rbp - 32]
	syscall

	; execve
	mov rax, SYS_EXECV
	mov rdi, [rbp - 40]
	mov rsi, [rbp - 48]
	mov rdx, [rbp - 56]
	syscall

.exit0:
	mov rdi, 0
.exit:
	mov rax, SYS_EXIT
	syscall

.err_nsp:
	mov rax, SYS_WRITE
	mov rdi, STDERR_FD
	mov rsi, err_msg_nsp
	mov rdx, err_msg_nsp_len
	syscall
	jmp .exit

.err_args:
	mov rax, SYS_WRITE
	mov rdi, STDERR_FD
	mov rsi, err_msg_args
	mov rdx, err_msg_args_len
	syscall
	jmp .exit

.err_perm:
	mov rax, SYS_WRITE
	mov rdi, STDERR_FD
	mov rsi, err_msg_perm
	mov rdx, err_msg_perm_len
	syscall
	jmp .exit

section .data
	procpath db "/proc/", 0
	scwd db "/cwd", 0
	sexe db "/exe", 0
	scmdline db "/cmdline", 0
	senviron db "/environ", 0
	scomm db "/comm", 0

	timespec:
	tv_sec dq 0
	tv_nsec dq 10000000

	err_msg_nsp db "No such process.", 10
	err_msg_nsp_len equ $ - err_msg_nsp

	err_msg_args db "Wrong arguments.", 10
	err_msg_args_len equ $ - err_msg_args

	err_msg_perm db "Wrong permission.", 10
	err_msg_perm_len equ $ - err_msg_perm

section .bss
	statbuf:
    st_dev resb 8;
    st_ino resb 8;
    st_nlink resb 8;

    st_mode resb 4;
    st_uid resb 4;
    st_gid resb 4;
    st_pad0 resb 4;
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
    st_unused resb 24;

