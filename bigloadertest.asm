; test of loading about 16MB

bits 32
org 0x100000

TEST_NUM equ 4000000

start:
	mov ebx, data
	mov ecx, TEST_NUM
	xor edx, edx
check_loop:
	mov eax, [ebx]
	cmp eax, edx
	jne ng
	add ebx, 4
	inc edx
	loop check_loop

	; test passed
	int 0

ng:
	int 8

data:
%assign i 0
%rep TEST_NUM
	dd i
%assign i i+1
%endrep
