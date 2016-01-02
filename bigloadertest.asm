bits 32
org 0x100000

start:
	mov ebx, data
	mov ecx, 10000000
	xor edx, edx
check_loop:
	mov eax, [ebx]
	cmp eax, edx
	jne ng
	add ebx, 4
	inc edx
	loop check_loop

	cli
ok:
	hlt
	jmp ok

ng:
	int 8

data:
%assign i 0
%rep 4000000
	dd i
%assign i i+1
%endrep
