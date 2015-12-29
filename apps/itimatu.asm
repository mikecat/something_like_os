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

	xor si, si
y_loop:
	xor di, di
x_loop:
	mov ax, si
	mov cl, 3
	shr ax, cl
	mov dx, di
	shr dx, cl
	add ax, dx
	xor dx, dx
	test ax, 1
	jz black
	inc dx
black:
	push dx
	push si
	push di
	call dot
	add sp, 6
	inc di
	cmp di, 320
	jl x_loop
	inc si
	cmp si, 200
	jl y_loop

	cli
owari:
	hlt
	jmp owari

	; void dot(int x, int y, int c)
dot:
	push di
	mov di, sp
	push es
	push bx
	mov ax, 0xA000
	mov es, ax
	mov ax, [di + 6]
	cmp ax, 0
	jl dot_ool
	cmp ax, 200
	jg dot_ool
	mov cx, 320
	mul cx
	mov dx, [di + 4]
	cmp dx, 0
	jl dot_ool
	cmp dx, 320
	jg dot_ool
	add ax, dx ;ax = y * 320 + x
	mov cx, [di + 8]
	mov bx, ax
	mov [es:bx], cl ; write pixel
dot_ool:
	pop bx
	pop es
	mov sp, di
	pop di
	ret
