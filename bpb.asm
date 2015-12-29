bits 16
cpu 8086
org 0x7C00

diskbuffer equ 0x7a00

loadaddr equ 0x0500

; only less than 0x10000 is supported!
max_size equ 0x7a00 - 0x0500

databegin:
	jmp start
	times 3-($-databegin) db 0x90
oemname: db 'LOADER  '
bytes_per_sector:    dw 0
sectors_per_cluster: db 0
reserved_sectors:    dw 0
number_of_fats:      db 0
root_entries:        dw 0
total_sectors:       dw 0
media_descriptor:    db 0
sectors_per_fat:     dw 0
sectors_per_track:   dw 0
heads:               dw 0
hidden_sectors:      dd 0
big_total_sectors:   dd 0
drive_number:        db 0
unused:              db 0
ext_boot_signature:  db 0
serial_number:       db 0xDE, 0xAD, 0xBE, 0xEF
volume_lavel:        db 'HOGESYSTEM '
file_system_type:    db 'FAT16   '

start:
	xor ax, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, 0x7FF0
	jmp 0:start2
start2:
	; store drive parameters
	mov [drive_number], dl
	mov ah, 0x08
	int 0x13
	mov dl, dh
	xor dh, dh
	inc dx
	mov [heads], dx
	and cx, 0x003F
	mov [sectors_per_track], cx

	; read RDE and search the file
	mov ax, [sectors_per_fat]
	mov bl, [number_of_fats]
	xor bh, bh
	mul bx ; DX:AX = number of sector of RDE
	mov cx, [root_entries] ; number of RDE sector
	xor bp, bp ; number of entry in current sector
	mov si, bx
	mov bx, diskbuffer ; address to read RDE data
searchfile_loop:
	test bp, bp
	jnz searchfile_no_read
	; read next sector
	call read_disk
	; increment sector number
	add ax, 1
	adc dx, 0
	mov bp, 16 ; set number of entries in a sector
	mov si, bx ; set address of the next entry
searchfile_no_read:
	push cx
	push si
	; compare file name
	mov cx, 11
	mov di, target_name
	cld
	repe cmpsb
	pop si
	pop cx
	je file_found
	dec bp ; decrement number of entries in a sector
	add si, 0x20 ; look at the next entry
	loop searchfile_loop
	; target not found
	mov si, notfoundmes
	jmp owata

file_found:
	; size check
	cmp word [si + 30], 0
	ja file_too_large
	cmp word [si + 28], max_size
	jbe file_size_ok
file_too_large:
	mov si, toolargemes
	jmp owata

file_size_ok:
	mov ax, [si + 26] ; AX = current clustor
	mov bx, [si + 28] ; file size
	add bx, 0x1FF
	mov cl, 9
	shr bx, cl
	mov cx, bx ; CX = number of sectors to read
	jcxz no_data ; won't accept file whose size = 0
	mov bx, loadaddr ; BX = where to load
	xor dh, dh
	mov dl, [sectors_per_cluster]
	mov si, dx ; sectors left in current cluster
	mov di, si ; setors per cluster
	push ax
	call fetch_fat
	cmp ax, 0x0001
	jbe invalid_fat ; if the first cluster is empty or reserved, error
	cmp ax, 0xFFF7
	je invalid_fat ; if the first cluster is bad, error
	pop ax
	push ax
	call cluster_to_sector ; DX:AX = current sector
file_read_loop:
	; read the sector
	call read_disk
	add bx, 0x200
	add ax, 1
	adc dx, 0
	dec cx
	jz file_read_end ; no sector left to read
	dec si
	jnz file_read_loop
	; proceed to the next cluster
	pop ax
	call fetch_fat
	cmp ax, 0x0001
	jbe invalid_fat
	cmp ax, 0xFFF7
	jae invalid_fat
	push ax
	call cluster_to_sector
	mov si, di
	jmp file_read_loop

file_read_end:
	; launch loaded program
	mov dl, [drive_number]
	jmp 0:loadaddr

no_data:
	mov si, nodatames
	jmp owata

invalid_fat:
	mov si, invalidfatmes
	jmp owata

	; put number of cluster to AX
	; the number of next cluster in AX
fetch_fat:
	push si
	mov si, ax
	and si, 0xff
	shl si, 1 ; index within the FAT sector
	mov al, ah
	xor ah, ah ; AX = number of FAT sector to read
	cmp ax, [cached_fat_sector]
	je fetch_fat_no_load
	push dx
	push bx
	mov [cached_fat_sector], ax
	xor dx, dx
	mov bx, diskbuffer
	call read_disk
	pop bx
	pop dx
fetch_fat_no_load:
	mov ax, [diskbuffer + si] ; read the FAT entry
	pop si
	ret

	; put cluster number to AX
	; sector number in DX:AX
cluster_to_sector:
	push cx
	push si
	sub ax, 2
	jb invalid_fat ; cluster number too small
	xor ch, ch
	mov cl, [sectors_per_cluster]
	mul cx ; DX:AX = offset of sector
	push dx
	push ax
	mov si, sp
	mov ax, [sectors_per_fat]
	mov cl, [number_of_fats]
	mul cx
	add [si], ax
	adc [si + 2], dx ; add number of sector for FAT
	mov ax, [root_entries]
	mov cl, 4
	shr ax, cl
	add [si], ax
	pop ax
	pop dx
	adc dx, 0 ; add number of sectors for RDE
	pop si
	pop cx
	ret

	; put sector number to DX:AX
	; put address to ES:BX
read_disk:
	push ax
	push cx
	push dx
	push bx
	; add hidden sectors and reserved sectors
	add ax, [hidden_sectors]
	adc dx, [hidden_sectors + 2]
	add ax, [reserved_sectors]
	adc dx, 0
	; calculate parameters
	div word [sectors_per_track]
	inc dx
	mov bx, dx ; BL = sector_number
	xor dx, dx
	div word [heads]
	mov dh, dl ; DH = head_number
	mov ch, al ; CH = cylinder_number[7:0]
	mov cl, 6
	shl ah, cl
	and bl, 0x3F
	mov cl, ah ; CL = {cylinder_number[9:8], 6'd0}
	or cl, bl ; CL = {cylinder_number[9:8], sector_number}
	mov dl, [drive_number] ; DL = drive_number
	pop bx
	mov ax, 0x0201
	int 0x13
	jc read_disk_error
	pop dx
	pop cx
	pop ax
	ret
read_disk_error:
	mov si, diskerrormes
	jmp owata

	; put the address of null-terminated string to si
owata:
	mov ah, 0x0e
	xor bx, bx
owata_loop:
	mov al, [si]
	test al, al
	jz owata_end
	int 0x10
	inc si
	jmp owata_loop
owata_end:
	cli
	hlt
	jmp owata_end

cached_fat_sector: ; variable: which sector of FAT is cached?
	dw 0xffff

diskerrormes:
	;db 'Disk error', 0
	db 'DE', 0

notfoundmes:
	;db 'Not found', 0
	db 'NF', 0

toolargemes:
	;db 'Too large', 0
	db 'TL', 0

nodatames:
	;db 'No data', 0
	db 'ND', 0

invalidfatmes:
	;db 'Invalid FAT', 0
	db 'IF', 0

target_name:
	db 'ENTRY   BIN'

	times 510-($-databegin) db 0x90
	db 0x55, 0xAA
