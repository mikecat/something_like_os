; read BPB of the disk partition and print it

bits 32
org 0x100000

start:
	mov ax, 0x0003
	int 0x30

	; read disk
	mov eax, 1
	mov ecx, 0
	mov edx, disk_buffer
	int 0x3C
	test eax, eax
	jz read_success
	push eax
	call print_dword
	add esp, 4
	jmp stop

read_success:
	mov esi, disk_buffer
	mov ecx, 0x200
dump_loop:
	xor eax, eax
	lodsb
	push ecx
	push eax
	call print_byte
	mov edx, [esp + 4]
	and edx, 0xF
	cmp edx, 1
	jne dump_not_newline
	mov dword [esp], 0x0D
	call putchar
	mov dword [esp], 0x0A
	call putchar
	jmp dump_loop_next
dump_not_newline:
	mov dword [esp], ' '
	call putchar
dump_loop_next:
	add esp, 4
	pop ecx
	loop dump_loop

stop:
	cli
stop_loop:
	hlt
	jmp stop_loop

	; int putchar(int c)
putchar:
	push ebp
	mov ebp, esp
	push ebx
	mov eax, [ebp + 8]
	mov ah, 0x0E
	xor bx, bx
	int 0x30
	pop ebx
	leave
	ret

	; int print_byte(int n)
print_byte:
	push ebp
	mov ebp, esp
	push ebx
	sub esp, 4
	mov ebx, [ebp + 8]
	mov eax, ebx
	shr eax, 4
	and eax, 0x0F
	add eax, '0'
	cmp eax, '9'
	jbe print_byte_digit1
	add eax, ('A' - ('9' + 1))
print_byte_digit1:
	mov [esp], eax
	call putchar
	mov eax, ebx
	and eax, 0x0F
	add eax, '0'
	cmp eax, '9'
	jbe print_byte_digit2
	add eax, ('A' - ('9' + 1))
print_byte_digit2:
	mov [esp], eax
	call putchar
	add esp, 4
	pop ebx
	leave
	ret

	; void print_dword(unsigned int n)
print_dword:
	push ebp
	mov ebp, esp
	sub esp, 12
	mov [ebp - 4], ebx
	mov ebx, [ebp + 8]
	mov ecx, 4
print_dword_loop:
	mov [ebp - 8], ecx
	rol ebx, 8
	mov eax, ebx
	and eax, 0xFF
	mov [esp], eax
	call print_byte
	mov ecx, [ebp - 8]
	loop print_dword_loop
	mov ebx, [ebp + 4]
	leave
	ret

disk_buffer:
	times 0x200 db 0
