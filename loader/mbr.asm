; load BPB of "active" pertition to 0x7C00 and jump to 0000:7C00

bits 16
CPU 8086
org 0x7A00

start:
	; check addrss and if executing from 0x7C00, copy to 0x7A00 and jump
	xor cx, cx
	mov ds, cx
	mov es, cx
	mov ss, cx
	mov sp, 0x7FF0
	call start2
start2:
	pop bx
	mov ax, cs
	mov cl, 4
	shl ax, cl
	add ax, bx
	cmp ax, 0x7C00
	jb load
	mov si, 0x7C00
	mov di, 0x7A00
	cld
	mov ch, 0x01 ; cx = 0x100
	rep movsw
	jmp 0:0x7A00

load:
	; start loading PBR
	; be careful not to break drive numbr in DL!
	xor dh, dh
	; check for bootable partitions
	mov bx, candidates
	mov si, record4
	mov cx, 4
checkloop:
	cmp byte [si], 0x80
	jne noboot
	mov [bx], cl
	inc bx
	inc dh
noboot:
	sub si, 16
	loop checkloop
	; is there any bootable partitions?
	test dh, dh
	jnz bootable_found
	mov si, nobootmes
	call puts
	jmp dead_end

bootable_found:
	cmp dh, 1
	ja select_partition
	mov bl, [candidates]
	jmp load_and_jump
select_partition:
	mov si, selectmes
	call puts
	xor ch, ch
	mov cl, dh
	mov si, bx
	xor bx, bx
	; print candidates
	mov ah, 0x0E
sel_disp_loop:
	dec si
	mov al, ' '
	int 0x10
	mov al, [si]
	add al, '0'
	int 0x10
	loop sel_disp_loop
	mov al, 13
	int 0x10
	mov al, 10
	int 0x10
sel_loop:
	; read key input
	xor ax, ax
	int 0x16
	; check the range of input
	cmp al, '1'
	jb sel_loop
	cmp al, '4'
	ja sel_loop
	sub al, '0'
	; check if the number is valid
	xor ah, ah
	mov bx, ax
	dec bx
	mov cl, 4
	shl bx, cl
	cmp byte [bx + record1], 0x80
	jne sel_loop
	; OK, proceed to load
	mov bl, al

load_and_jump:
	mov si, partitionselmes
	call puts
	push bx
	mov al, bl
	add al, '0'
	mov ah, 0x0E
	xor bx, bx
	int 0x10
	mov si, partitionselmes2
	call puts
	pop bx
	xor bh, bh
	dec bl
	mov cl, 4
	shl bx, cl
	add bx, record1 + 1
	mov dh, [bx]
	mov cx, [bx + 1]
	mov ax, 0x0201
	mov bx, 0x7C00
	int 0x13
	jc read_failed
	jmp pbr_start
read_failed:
	mov si, readfailmes
	call puts
	mov cl, 4
	rol al, cl
	call puthex
	rol al, cl
	call puthex
	xor bx,bx
	mov ax, 0x0E0D
	int 0x10
	mov al, 0x0A
	int 0x10
	; jmp dead_end

	; owata
dead_end:
	mov si, deadmes
	call puts
dead_end_loop:
	xor ax, ax
	int 0x16
	cmp al, 'R'
	je int_19
	cmp al, 'r'
	je int_19
	cmp al, 'B'
	je int_18
	cmp al, 'b'
	je int_18
	jmp dead_end_loop
int_18:
	int 0x18
int_19:
	int 0x19
wont_come_here:
	cli
	hlt
	jmp wont_come_here

	; put the address of null-terminated string to si
	; si will be destroyed
puts:
	push ax
	push bx
	mov ah, 0x0e
	xor bx, bx
puts_loop:
	mov al, [si]
	test al, al
	jz puts_end
	int 0x10
	inc si
	jmp puts_loop
puts_end:
	pop bx
	pop ax
	ret

	; print lower 4 bit of AL
puthex:
	push ax
	push bx
	mov ah, 0x0E
	and al, 0x0F
	add al, '0'
	cmp al, '9'
	jbe noalphabet
	add al, 7
noalphabet:
	xor bx, bx
	int 0x10
	pop bx
	pop ax
	ret

candidates:
	times 4 db 0
nobootmes:
	db 'No bootable partitions found.', 13, 10, 0
selectmes:
	db 'Select partition from', 0
partitionselmes:
	db 'Partition ', 0
partitionselmes2:
	db ' selected.', 13, 10, 0
readfailmes:
	db 'Disk read failed: 0x', 0
deadmes:
	db 'Failed. Press R/B', 13, 10, 0

	times 446-($-start) db 0x90
record1:
	times 16 db 0x00
record2:
	times 16 db 0x00
record3:
	times 16 db 0x00
record4:
	times 16 db 0x00

	db 0x55, 0xAA
pbr_start:
