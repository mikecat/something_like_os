bits 16
cpu 8086

start:
	mov ah, 0x08
	int 0x13
	mov si, cx
	xor bx, bx
	mov ah, 0x0E
	mov al, 'C'
	int 0x10
	mov al, 'X'
	int 0x10
	mov al, ' '
	int 0x10
	mov al, '='
	int 0x10
	mov al, ' '
	int 0x10
	mov cl, 4
	mov ax, si
	mov al, ah
	shr al, cl
	and al, 0x0F
	mov ah, 0x0E
	add al, '0'
	cmp al, '9'
	jbe L1
	add al, 7
L1:
	int 0x10
	mov ax, si
	mov al, ah
	and al, 0x0F
	mov ah, 0x0E
	add al, '0'
	cmp al, '9'
	jbe L2
	add al, 7
L2:
	int 0x10
	mov ax, si
	shr al, cl
	and al, 0x0F
	mov ah, 0x0E
	add al, '0'
	cmp al, '9'
	jbe L3
	add al, 7
L3:
	int 0x10
	mov ax, si
	and al, 0x0F
	mov ah, 0x0E
	add al, '0'
	cmp al, '9'
	jbe L4
	add al, 7
L4:
	int 0x10
	mov al, 13
	int 0x10
	mov al, 10
	int 0x10
	mov al, 'D'
	int 0x10
	mov al, 'X'
	int 0x10
	mov al, ' '
	int 0x10
	mov al, '='
	int 0x10
	mov al, ' '
	int 0x10
	mov ax, dx
	mov al, ah
	shr al, cl
	and al, 0x0F
	mov ah, 0x0E
	add al, '0'
	cmp al, '9'
	jbe L5
	add al, 7
L5:
	int 0x10
	mov ax, dx
	mov al, ah
	and al, 0x0F
	mov ah, 0x0E
	add al, '0'
	cmp al, '9'
	jbe L6
	add al, 7
L6:
	int 0x10
	mov ax, dx
	shr al, cl
	and al, 0x0F
	mov ah, 0x0E
	add al, '0'
	cmp al, '9'
	jbe L7
	add al, 7
L7:
	int 0x10
	mov ax, dx
	and al, 0x0F
	mov ah, 0x0E
	add al, '0'
	cmp al, '9'
	jbe L8
	add al, 7
L8:
	int 0x10
	mov al, 13
	int 0x10
	mov al, 10
	int 0x10
	cli
owari:
	hlt
	jmp owari
