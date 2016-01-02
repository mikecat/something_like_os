; draw check puttern by writing to VRAM from protected mode

bits 16
org 0x0500

start:
	; set screen to 320x200
	mov ax, 0x0013
	int 0x10
	; set palette
	mov ax, 0x1010
	xor bx, bx
	xor dh, dh
	xor cx, cx
	int 0x10 ; palette[0] = RGB(0, 0, 0)
	inc bx
	mov dh, 0xFF
	mov cx, 0xFFFF
	int 0x10 ; palette[1] = RGB(255, 255, 255)

	; load GDT
	cli
	lgdt [gdt_ptr]
	; switch to protected mode
	mov eax, cr0
	or eax, 1 ; enable PE
	and eax, 0x7fffffff ; disable PG
	mov cr0, eax
	jmp 0x8:pcode

	align 8
gdt_ptr:
	dw 8 * 3
	dd gdt

	align 8
gdt:
	; null segment
	dd 0, 0
	; code segment
	dd 0x0000FFFF
	dd 0b00000000_1100_1111_1001_1010_00000000
	; data segment
	dd 0x0000FFFF
	dd 0b00000000_1100_1111_1001_0010_00000000

bits 32
	align 16
pcode:
	mov ax, 0x10
	mov ss, ax
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov esp, 0x7FF0 ; 4-byte align

	xor esi, esi
y_loop:
	xor edi, edi
x_loop:
	mov eax, esi
	shr eax, 3
	mov edx, edi
	shr edx, 3
	add eax, edx
	xor edx, edx
	test eax, 1
	jz black
	inc edx
black:
	push edx
	push esi
	push edi
	call dot
	add esp, 12
	inc edi
	cmp edi, 320
	jl x_loop
	inc esi
	cmp esi, 200
	jl y_loop

	cli
owari:
	hlt
	jmp owari

	; void dot(int x, int y, int c)
dot:
	push ebp
	mov ebp, esp
	mov eax, [ebp + 12]
	cmp eax, 0
	jl dot_ool
	cmp eax, 200
	jg dot_ool
	mov ecx, 320
	mul ecx
	mov edx, [ebp + 8]
	cmp edx, 0
	jl dot_ool
	cmp edx, 320
	jg dot_ool
	add eax, edx ; eax = y * 320 + x
	mov ecx, [ebp + 16]
	add eax, 0xA0000
	mov [eax], cl ; write pixel
dot_ool:
	leave
	ret
