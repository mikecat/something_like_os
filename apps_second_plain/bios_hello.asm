; print "hello, world!" via wrapped BIOS call

bits 32
org 0x100000

start:
	mov ax, 0x0003
	int 0x30
	push hello
	call puts
	add esp, 4

	cli
stop_loop:
	hlt
	jmp stop_loop

hello:
	db 'hello, world!', 0

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

	; void puts(int c)
puts:
	push ebp
	mov ebp, esp
	push esi
	sub esp, 4
	mov esi, [ebp + 8]
puts_loop:
	mov al, [esi]
	test al, al
	jz puts_end
	movzx eax, al
	mov [esp], eax
	call putchar
	inc esi
	jmp puts_loop
puts_end:
	mov dword [esp], 0x0D
	call putchar
	mov dword [esp], 0x0A
	call putchar
	pop esi
	leave
	ret
