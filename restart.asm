bits 64
default rel

BLOCK_SIZE equ 1024
BLOCK_MASK equ BLOCK_SIZE - 1

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
SYS_CHDIR equ 80
SYS_RLINK equ 89
SYS_GUID  equ 102
SYS_SUID  equ 105
SYS_SSID  equ 112

section .text

atoi:
	mov rdi, 0

_a0:
	cmp byte [rax], 0
	je _a1

	mul rdi, 10
	movzx rsi, byte [rax]
	sub rsi, '0'
	add rdi, rsi
	inc rax

	jmp _a0
_a1:
	mov rax, rdi
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
	inc rax
	jmp _sl0
_sl1:
	sub rax, rdi
	ret

strmov:
_sm0:
	mov sil, [rdi]
	mov [rax], sil
	cmp sil, 0
	je _sm1
	inc rax
	inc rdi
	jmp _sm0
_sm1:
	ret

strcat:
_sc0:
	cmp byte [rax], 0
	je _sc1
	inc rax
	jmp _sc0
_sc1:
	call strmov
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
	; rax : file path

	; -8  : file path

	push rbp
	mov rbp, rsp
	sub rsp, 8

	mov [rbp - 8], rax

	call reserve_block

	mov rsi, rax
	mov rax, SYS_RLINK
	mov rdi, [rbp - 8]
	mov rdx, BLOCK_SIZE
	syscall

	mov byte [rsi + rax], 0

	mov rax, rsi

	mov rsp, rbp
	pop rbp
	ret

read_file:
	; rax : file path

	; -8  : file descriptor
	; -16 : data ptr
	; -24 : bytes read

	push rbp
	mov rbp, rsp
	sub rsp, 24

	mov rdi, rax
	mov rax, SYS_OPEN
	mov rsi, O_RDONLY
	xor rdx, rdx
	syscall

	mov [rbp - 8], rax

	call reserve_block
	mov [rbp - 16], rax

	mov qword [rbp - 24], 0

_rf0:
	mov rsi, rax
	mov rax, SYS_READ
	mov rdi, [rbp - 8]
	mov rdx, BLOCK_SIZE
	syscall

	add [rbp - 24], rax

	cmp rax, BLOCK_SIZE
	jne _rf1

	call reserve_block
	jmp _rf0

_rf1:
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

	; rax : out ptr
	; rbx : out end
	; rcx : in ptr
	; rdx : in end

	mov rcx, rax
	mov rdx, rdi
	add rdx, rcx

	push rcx
	call reserve_block
	pop rcx
	mov rbx, rax
	add rbx, BLOCK_SIZE
	push rax

_mpp0:
	cmp rcx, rdx
	jge _mpp3

	mov qword [rax], rcx
	add rax, 8

	cmp rax, rbx
	jne _mpp4

	push rax
	push rcx
	call reserve_block
	pop rcx
	pop rax

	add rbx, BLOCK_SIZE

_mpp4:

	mov qword [rax], 0

_mpp1:
	cmp byte [rcx], 0
	je _mpp2

	inc rcx

	jmp _mpp1
_mpp2:

	inc rcx
	jmp _mpp0
_mpp3:

	pop rax
	
	mov rsp, rbp
	pop rbp

	ret

global _start
_start:
	; + 8 : argv
	;   0 : argc
	; - 8 : basepath
	; -16 : append ptr
	; -24 : uid
	; -32 : cwd
	; -40 : exe
	; -48 : cmdline
	; -56 : environ
	; -64 : pid but int

	mov rbp, rsp
	sub rsp, 64

	cmp [rbp], 2
	jne err_args

	; path stuff
	; /proc/1234

	mov rax, [rbp + 16]
	call atoi
	mov [rbp - 64], rax

	call reserve_block
	mov [rbp - 8], rax

	mov rdi, procpath
	call strmov
	mov rax, [rbp - 8]
	mov rdi, [rbp + 16]
	call strcat

	; points to the end of the base path
	mov rax, [rbp - 8]
	mov [rbp - 16], rax
	call strlen
	add [rbp - 16], rax

	mov rax, [rbp - 8]
	call stat_file

	; if stat returns negative, it probably doesn't exist
	cmp rax, 0
	jne err_nsp

	; save uid
	mov eax, [st_uid]
	mov [rbp - 24], rax

	mov rax, SYS_GUID
	syscall

	; ensure we have permission
	cmp rax, 0
	je root_or_matching
	
	cmp rax, [rbp - 24]
	je root_or_matching

	jmp err_perm

root_or_matching:

	; get cwd of process
	mov rax, [rbp - 16]
	mov rdi, scwd
	call strmov

	mov rax, [rbp - 8]
	call readlink
	
	mov [rbp - 32], rax

	; get exe of process
	mov rax, [rbp - 16]
	mov rdi, sexe
	call strmov

	mov rax, [rbp - 8]
	call readlink

	mov [rbp - 40], rax

	; get cmdline of process
	mov rax, [rbp - 16]
	mov rdi, scmdline
	call strmov

	mov rax, [rbp - 8]
	call read_file

	mov rdi, rdx
	call make_ptrptr
	mov [rbp - 48], rax

	; get environ of process
	mov rax, [rbp - 16]
	mov rdi, senviron
	call strmov

	mov rax, [rbp - 8]
	call read_file

	mov rdi, rdx
	call make_ptrptr
	mov [rbp - 56], rax

	; kill
	mov rax, SYS_KILL
	mov rdi, [rbp - 64]
	mov rsi, 2
	syscall

	; wait for it to die
waiting:
	; check process
	mov rax, SYS_KILL
	mov rdi, [rbp - 64]
	mov rsi, 0
	syscall

	cmp rax, 0
	jne done_waiting

	; wait
	mov rax, SYS_SLEEP
	mov rdi, timespec
	mov rsi, 0
	syscall
	jmp waiting
done_waiting:

	; fork
	mov rax, SYS_FORK
	syscall

	cmp rax, 0
	jne exit0

	; setuid
	mov rax, SYS_SUID
	mov rdi, [rbp - 24]
	syscall

	; setsid
	mov rax, SYS_SSID
	syscall

	; close stdout
	mov rax, SYS_CLOSE
	mov rdi, 1
	syscall

	; chdir
	mov rax, SYS_CHDIR
	mov rdi, [rbp - 32]
	syscall

	cmp rax, 0
	jne err_nsp

	; execve
	mov rax, SYS_EXECV
	mov rdi, [rbp - 40]
	mov rsi, [rbp - 48]
	mov rdx, [rbp - 56]
	syscall

exit0:
	mov rdi, 0
exit:
	mov rax, SYS_EXIT
	syscall

err_nsp:
	mov rax, SYS_WRITE
	mov rdi, 1
	mov rsi, err_msg_nsp
	mov rdx, err_msg_nsp_len
	syscall
	jmp exit

err_args:
	mov rax, SYS_WRITE
	mov rdi, 1
	mov rsi, err_msg_args
	mov rdx, err_msg_args_len
	syscall
	jmp exit

err_perm:
	mov rax, SYS_WRITE
	mov rdi, 1
	mov rsi, err_msg_perm
	mov rdx, err_msg_perm_len
	syscall
	jmp exit

section .data
	procpath db "/proc/", 0
	scwd db "/cwd", 0
	sexe db "/exe", 0
	scmdline db "/cmdline", 0
	senviron db "/environ", 0
	
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

