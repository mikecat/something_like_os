bits 16
org 0x0500

initial_stack equ 0x1FFF0
stack_end equ 0x10000

pde_addr equ 0x20000
pte_addr equ 0x21000
idt_addr equ 0x22000

start:
	cli
	mov [disk_no], dl
	jmp start2

disk_no:
	db 0

	align 8
gdt_ptr:
	dw 8 * 5
	dd gdt
idt_ptr:
	dw 8 * 256
	dd idt_addr

	align 8
gdt:
	; null segment
	dd 0, 0
	; 32-bit code segment
	dd 0x0000FFFF
	dd 0b00000000_1100_1111_1001_1010_00000000
	; 32-bit data segment
	dd 0x0000FFFF
	dd 0b00000000_1100_1111_1001_0010_00000000
	; 16-bit code segment
	dd 0x0000FFFF
	dd 0b00000000_0000_0000_1001_1010_00000000
	; 16-bit data segment
	dd 0x0000FFFF
	dd 0b00000000_0000_0000_1001_0010_00000000

wait_read_keyboard: ; wait while keyboard -> CPU busy
	in al, 0x64
	test al, 0x01
	jz wait_read_keyboard
	ret

wait_write_keyboard: ; wait while CPU -> keyboard busy
	in al, 0x64
	test al, 0x02
	jnz wait_write_keyboard
	ret

start2:
	; unlock A20
	call wait_write_keyboard
	mov al, 0xAD
	out 0x64, al ; disable keyboard
	call wait_write_keyboard
	mov al, 0xD0
	out 0x64, al
	call wait_read_keyboard
	in al, 0x60 ; read output port
	mov ah, al
	or ah, 0x02 ; enable A20
	call wait_write_keyboard
	mov al, 0xD1
	out 0x64, al
	call wait_write_keyboard
	mov al, ah
	out 0x60, al ; write output port with A20 enabled
	call wait_write_keyboard
	mov al, 0xAE
	out 0x64, al ; enable keyboard
	call wait_write_keyboard

	; go to protected mode
	lgdt [gdt_ptr]
	mov eax, cr0
	or eax, 0x00010001 ; enable PE and WP
	mov cr0, eax
	jmp 8:pstart

bits 32
	; put int number on stack, then call
	; the int number will be automatically removed
soft_int:
	pushfd
	cli
	; save registers
	mov [si_eax], eax
	pop eax
	mov [si_eflags], eax
	mov eax, [esp + 4]
	mov [si_ino], eax
	call 8:soft_int2
soft_int2:
	mov [si_ecx], ecx
	mov [si_edx], edx
	mov [si_ebx], ebx
	mov [si_esi], esi
	mov [si_edi], edi
	mov [si_esp], esp
	mov [si_ebp], ebp
	mov [si_ds], ds
	mov [si_es], es
	mov [si_ss], ss
	mov [si_fs], fs
	mov [si_gs], gs
	sidt [si_idt]
	mov eax, cr3
	mov [si_cr3], eax

	; disable paging
	mov word [si_idt_zero], 0x400
	mov dword [si_idt_zero + 2], 0
	lidt [si_idt_zero]
	mov eax, cr0
	and eax, 0x7FFFFFFF
	mov cr0, eax
	xor eax, eax
	mov cr3, eax

	; switch to real mode
	jmp 24:si_16bit
bits 16
si_16bit:
	mov ax, 32
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax
	mov sp, 0x7FF0
	mov eax, cr0
	and eax, 0x7FFFFFFE
	mov cr0, eax
	jmp 0:si_real
si_real:
	xor ax, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax

	; determine which service is called
	mov ax, [si_ino]
	sub ax, 0x10
	jb si_calc_error
	cmp ax, 0x0A
	ja si_calc_error
	mov bx, (si_int_11 - si_int_10)
	mul bx
	add ax, si_int_10
	mov [si_int_addr], ax
	jmp si_calc_end
si_calc_error:
	mov word [si_int_addr], si_int_end
si_calc_end:
	; restore registers as parameters for BIOS
	mov ax, [si_eax]
	mov cx, [si_ecx]
	mov dx, [si_edx]
	mov bx, [si_ebx]
	mov si, [si_esi]
	mov di, [si_edi]
	mov bp, [si_ebp]
	; do BIOS call
	jmp [si_int_addr]
si_int_10:
	int 0x10
	jmp strict short si_int_end
si_int_11:
%assign i 0x11
%rep 0x1A - 0x11 + 1
	int i
	jmp strict short si_int_end
%assign i i+1
%endrep
si_int_end:
	cli
	; save registers which may contain return values from BIOS
	mov [si_eax], ax
	mov [si_ecx], cx
	mov [si_edx], dx
	mov [si_ebx], bx
	mov [si_esi], si
	mov [si_edi], di
	pushfd
	pop ax
	and ax, 0x08D5
	and word [si_eflags], 0xF72A
	or [si_eflags], ax

	; switch to protected mode
	mov eax, cr0
	or eax, 0x00000001
	mov cr0, eax
	jmp 8:si_protected
bits 32
si_protected:
	mov ax, 16
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax

	; enable paging
	mov eax, [si_cr3]
	mov cr3, eax
	mov eax, cr0
	or eax, 0x80000000
	mov cr0, eax

	; restore registers
	mov esp, [si_esp]
	mov eax, soft_int_ret
	mov [esp], eax ; new EIP
	retf
soft_int_ret:
	lidt [si_idt]
	mov eax, [si_eax]
	mov ecx, [si_ecx]
	mov edx, [si_edx]
	mov ebx, [si_ebx]
	mov esi, [si_esi]
	mov edi, [si_edi]
	mov ebp, [si_ebp]
	mov ds, [si_ds]
	mov es, [si_es]
	mov ss, [si_ss]
	mov fs, [si_fs]
	mov gs, [si_gs]
	push dword [si_eflags]
	popfd
	ret 4

int_hardware:
	push strict dword 0
	jmp strict long int_hardware_start
int_hardware_delta:
%assign i 1
%rep 255 - 1 + 1
	push strict dword i
	jmp strict long int_hardware_start
%assign i i+1
%endrep
int_hardware_start:
	cli
	pusha
	mov eax, [esp + 32]
	push eax
	mov eax, [int_handler_addr]
	test eax, eax
	jz int_hardware_none
	call eax
int_hardware_none:
	add esp, 4 ; remove interrupt number as argument
	popa
	; remove interrupt number if error code is likely to exist
	cmp dword [esp], 8
	je int_hardware_remove_error_code
	cmp dword [esp], 17
	je int_hardware_remove_error_code
	cmp dword [esp], 10
	jb int_hardware_no_error_code
	cmp dword [esp], 14
	ja int_hardware_no_error_code
int_hardware_remove_error_code:
	add esp, 4
int_hardware_no_error_code:
	add esp, 4 ; remove interrupt number or error code
	sti
	iret

align 4
sector_num:   dd 0
head_num:     dd 0
cylinder_num: dd 0

fat_begin_sector: dd 0 ; where the first FAT begins?
fat_number:       dd 0 ; how many FATs are there in this partition?
fat_size:         dd 0 ; number of sectors in one FAT
cluster_size:     dd 0 ; number of sectors in one cluster
root_entry_size:  dd 0 ; number of entries in root entry
disk_size:        dd 0 ; number of sectors in this partition

	; int disk_init(void)
	; return 0 if no error, error code on error
	; error code 0x100 = unsupported sector size
	; error code 0x101 = unsupported FAT type
disk_init:
	push ebx
	push esi
	push edi
	; read file system parameters from BPB
	; check sector size
	mov ax, [bpb_bytes_per_sector]
	cmp ax, 0x200
	je disk_init_sector_size_ok
	mov ax, 0x100
	jmp disk_init_end
disk_init_sector_size_ok:
	; calculate the first sector of FAT
	mov ax, [bpb_reserved_sectors]
	movzx eax, ax
	add eax, [bpb_hidden_sectors]
	mov [fat_begin_sector], eax
	; read parameters
	mov al, [bpb_number_of_fats]
	movzx eax, al
	mov [fat_number], eax
	mov ax, [bpb_sectors_per_fat]
	movzx eax, ax
	mov [fat_size], eax
	mov al, [bpb_sectors_per_cluster]
	movzx eax, al
	mov [cluster_size], eax
	mov ax, [bpb_root_entries]
	movzx eax, ax
	mov [root_entry_size], eax
	mov ax, [bpb_total_sectors]
	movzx eax, ax
	test eax, eax
	jnz disk_init_sector_not_big
	mov eax, [bpb_big_total_sectors]
disk_init_sector_not_big:
	mov [disk_size], eax
	; check FAT type
	xor edx, edx
	div dword [cluster_size]
	cmp eax, 4085
	jbe disk_init_fat_type_ng
	cmp eax, 65525
	jbe disk_init_fat_type_ok
disk_init_fat_type_ng:
	mov eax, 0x101
	jmp disk_init_end
disk_init_fat_type_ok:
	; get disk parameters from BIOS
	mov ah, 0x08
	mov dl, [disk_no]
	push 0x13
	call soft_int
	jnc disk_init_ok
	mov al, ah
	movzx eax, al
	jmp disk_init_end
disk_init_ok:
	; number of heads
	mov al, dh
	movzx eax, al
	inc eax
	mov [head_num], eax
	; number of sectors per track
	mov al, cl
	and al, 0x3F
	movzx eax, al
	mov [sector_num], eax
	; number of cylinders
	xor eax, eax
	mov al, ch
	mov ah, cl
	shr ah, 6
	inc eax
	mov [cylinder_num], eax
	xor eax, eax
disk_init_end:
	pop edi
	pop esi
	pop ebx
	ret

pstart:
	mov ax, 16
	mov ss, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax
	mov esp, initial_stack

	; initialize master PIC
	mov al, 0b00010001 ; ICW1
	out 0x20, al
	mov al, 0x20 ; ICW2
	out 0x21, al
	mov al, 0b00000100 ; ICW3
	out 0x21, al
	mov al, 0b00000001 ; ICW4
	out 0x21, al
	mov al, 0b11111111 ; OCW1
	out 0x21, al
	; initialize slave PIC
	mov al, 0b00010001 ; ICW1
	out 0xA0, al
	mov al, 0x28 ; ICW2
	out 0xA1, al
	mov al, 0x02 ; ICW3
	out 0xA1, al
	mov al, 0b00000001 ; ICW4
	out 0xA1, al
	mov al, 0b11111111 ; OCW1
	out 0xA1, al

	; initialize IDT
	mov dword [int_handler_addr], 0
	mov ax, 0b10001_110_000_00000
	mov ebx, idt_addr ; the address of entry in table
	mov edx, int_hardware ; where to jump on interrupt
	mov ecx, 256
init_idt_loop:
	mov [ebx], dx
	mov word [ebx + 2], 8
	mov [ebx + 4], ax
	ror edx, 16
	mov [ebx + 6], dx
	ror edx, 16
	add ebx, 8
	add edx, (int_hardware_delta - int_hardware)
	loop init_idt_loop
	lidt [idt_ptr]
	sti

	; initialize PDE
	xor eax, eax
	mov edi, pde_addr
	mov ecx, 0x400
	rep stosd
	mov dword [pde_addr], (pte_addr & 0xFFFFF000) | 0b000000_000011
	; initialize PTE
	; identity map for first 1MB
	mov eax, 0x00000003
	mov edi, pte_addr
	mov ecx, 0x100
init_pte_loop:
	stosd
	add eax, 0x1000
	loop init_pte_loop
	; disable left
	xor eax, eax
	mov ecx, 0x300
	rep stosd
	; disable caching for VRAM
	mov esi, pte_addr + ((0xA0000 >> 12) << 2)
	mov edi, esi
	mov ecx, 20
init_pte_loop2:
	lodsd
	or eax, 0x18
	stosd
	loop init_pte_loop2
	; protect data from stack becoming too big by removing a page
	and dword [pte_addr + ((stack_end >> 12) << 2)], 0xFFFFFFFC
	; enable paging
	mov eax, pde_addr
	mov cr3, eax

	; initialize screen
	mov ax, 0x0003
	push 0x10
	call soft_int

	; initialize disk
	call disk_init
	test eax, eax
	jz init_disk_ok
	push eax
	push disk_init_ng_mes
	call putstr
	pop eax
	call printhex
	pop eax
	jmp exit
init_disk_ok:
	; protect disk information by making first 0x8000 bytes read-only
	mov esi, pte_addr
	mov edi, esi
	mov ecx, 8
disk_readonly_loop:
	lodsd
	and eax, 0xFFFFFFFD
	stosd
	loop disk_readonly_loop
	jmp app_start

	; int read_sector(void* addr, unsigned int lba)
	; return 0 if no error, error code if error
	; error code 0x100 = lba too large
	; error code 0x101 = disk information error (not initialized?)
read_sector:
	push ebp
	mov ebp, esp
	push ebx
	push esi
	push edi
	; disk information check
	mov eax, [sector_num]
	test eax, eax
	jz read_sector_parameter_error
	cmp eax, 0x3F
	ja read_sector_parameter_error
	mov eax, [head_num]
	test eax, eax
	jz read_sector_parameter_error
	cmp eax, 0x100
	ja read_sector_parameter_error
	mov eax, [cylinder_num]
	test eax, eax
	jz read_sector_parameter_error
	cmp eax, 0x400
	ja read_sector_parameter_error
	jmp read_sector_parameter_ok
read_sector_parameter_error:
	mov eax, 0x101
	jmp read_sector_end
read_sector_parameter_ok:
	; convert LBA to CHS
	mov eax, [ebp + 12]
	xor edx, edx
	div dword [sector_num]
	inc edx
	mov ebx, edx ; sector number
	xor edx, edx
	div dword [head_num] ; EAX = cylinder number, EDX = head number
	cmp eax, [cylinder_num]
	jb read_sector_cylinder_ok
	; cylinder number too large
	mov eax, 0x100
	jmp read_sector_end
read_sector_cylinder_ok:
	mov dh, dl
	mov dl, [disk_no]
	mov ch, al
	mov cl, ah
	shl cl, 6
	and bl, 0x3F
	or cl, bl
	mov ax, 0x0201
	mov bx, read_disk_buffer_addr
	push 0x13
	call soft_int
	jnc read_sector_ok
	; error
	mov al, ah
	movzx eax, al
	jmp read_sector_end
read_sector_ok:
	; copy data read
	mov esi, read_disk_buffer_addr
	mov edi, [ebp + 8]
	mov ecx, 128
	rep movsd
	xor eax, eax
read_sector_end:
	pop edi
	pop esi
	pop ebx
	leave
	ret

	; int putchar(int c)
putchar:
	push ebp
	mov ebp, esp
	push ebx
	mov ah, 0x0E
	mov al, [ebp + 8]
	xor ebx, ebx
	push 0x10
	call soft_int
	xor eax, eax
	mov al, [ebp + 8]
	pop ebx
	leave
	ret

	; void putstr(const char* str)
putstr:
	push ebp
	mov ebp, esp
	push ebx
	push esi
	sub esp, 4
	mov esi, [ebp + 8]
	mov ah, 0x0e
	xor bx, bx
putstr_loop:
	xor eax, eax
	mov al, [esi]
	test al, al
	jz putstr_end
	inc esi
	mov [esp], eax
	call putchar
	jmp putstr_loop
putstr_end:
	add esp, 4
	pop esi
	pop ebx
	leave
	ret

	; void printhex(unsigned int n)
printhex:
	push ebp
	mov ebp, esp
	sub esp, 12
	mov eax, [ebp + 8]
	mov [ebp - 4], eax
	mov dword [ebp - 8], 8
printhex_loop:
	mov eax, [ebp - 4]
	rol eax, 4
	mov [ebp - 4], eax
	and eax, 0xF
	add eax, '0'
	cmp eax, '9'
	jbe printhex_noalpha
	add eax, 'A' - ('9' + 1)
printhex_noalpha:
	mov [esp], eax
	call putchar
	dec dword [ebp - 8]
	jnz printhex_loop
	leave
	ret

	; int read_fat(int cluster_no)
	; return the FAT entry
	; index error -> return -0x10000
	; disk read error -> return -(error code)
read_fat:
	push ebp
	mov ebp, esp
	mov eax, [ebp + 8]
	cmp eax, 0
	jl read_fat_index_error ; negative index -> error
	movzx ecx, al ; index within the sector
	shr eax, 8 ; the index of sector
	cmp eax, [fat_size]
	jae read_fat_index_error ; index too large
	cmp eax, [fat_cache_sector]
	je read_fat_cache_hit
	; cache miss, read the disk
	push eax
	push ecx
	add eax, [fat_begin_sector]
	push eax ; sector number
	push fat_cache ; address
	call read_sector
	add esp, 8
	test eax, eax
	jz read_fat_read_ok
	; read error
	add esp, 8
	neg eax
	jmp read_fat_end
read_fat_read_ok:
	pop ecx
	pop eax
	mov [fat_cache_sector], eax
read_fat_cache_hit:
	; get the data in the sector
	shl ecx, 1
	mov ax, [fat_cache + ecx]
	movzx eax, ax
	jmp read_fat_end
read_fat_index_error:
	mov eax, -0x10000
read_fat_end:
	leave
	ret

	; int search_file(int *cluster, unsigned int *size, const char *name)
	; successfully found -> return 0
	; not found -> return -1
	; disk read error -> return (error code)
search_file:
	push ebp
	mov ebp, esp
	; int [ebp - 4] : save ESI
	; int [ebp - 8] : save EDI
	mov [ebp - 4], esi
	mov [ebp - 8], edi
	; char [ebp - 20][12] : file name on RDE to search
	; int [ebp - 24] : entries left in this secctor
	; int [ebp - 28] : entries left
	; int [ebp - 32] : current sector number
	sub esp, 32
	; check if name is NULL
	mov esi, [ebp + 16]
	test esi, esi
	jz search_file_not_found
	; convert name to format for RDE
	mov al, ' '
	mov ecx, 11
	lea edi, [ebp - 20]
	rep stosb
	; save filename
	mov ecx, 8
	mov esi, [ebp + 16]
	lea edi, [ebp - 20]
search_file_convert_filename:
	lodsb
	; delimiter of filename and extension
	cmp al, '.'
	je search_file_convert_filename_end
	; end of string
	cmp al, 0
	je search_file_convert_extension_end
	; make letters upper case
	cmp al, 'a'
	jb search_file_filename_no_toupper
	cmp al, 'z'
	ja search_file_filename_no_toupper
	add al, ('A' - 'a')
search_file_filename_no_toupper:
	stosb
	loop search_file_convert_filename
	; skip until '.' or '\0'
search_file_skip_until_extension:
	mov al, [esi]
	inc esi
	cmp al, '.'
	je search_file_convert_filename_end
	cmp al, 0
	je search_file_convert_extension_end
	jmp search_file_skip_until_extension
search_file_convert_filename_end:
	; save extension
	mov ecx, 3
	; no need to change ESI
	lea edi, [ebp - 12] ; [ebp - 20 + 8]
search_file_convert_extension:
	lodsb
	; end of string
	cmp al, 0
	je search_file_convert_extension_end
	; make letters upper case
	cmp al, 'a'
	jb search_file_extension_no_toupper
	cmp al, 'z'
	ja search_file_extension_no_toupper
	add al, ('A' - 'a')
search_file_extension_no_toupper:
	stosb
	loop search_file_convert_extension
search_file_convert_extension_end:
	; test
	mov byte [ebp - 9], 0
	push '"'
	call putchar
	lea eax, [ebp - 20]
	mov [esp], eax
	call putstr
	mov dword [esp], '"'
	call putchar
	mov dword [esp], 0x0D
	call putchar
	mov dword [esp], 0x0A
	call putchar
	add esp, 4
	jmp search_file_end
	; calculate first sector number of RDE
	mov eax, [fat_size]
	mul dword [fat_number]
	add eax, [fat_begin_sector]
	mov [ebp - 32], eax
	jmp search_file_end
search_file_not_found:
	mov eax, -1
search_file_end:
	; restore saved registers
	mov esi, [ebp - 4]
	mov edi, [ebp - 8]
	leave
	ret

interrupt_handler:
	push ebp
	mov ebp, esp
	push ebx
	mov eax, [ebp + 8]
	cmp eax, 0x20
	jae interrupt_handler_ret
	push interrupt_message
	call putstr
	mov eax, [ebp + 8]
	mov [esp], eax
	call printhex
	mov dword [esp], 0x0D
	call putchar
	mov dword [esp], 0x0A
	call putchar
	add esp, 4
	jmp exit
interrupt_handler_ret:
	pop ebx
	leave
	ret

interrupt_message:
	db 13, 10, 'Trap : ', 0

app_start:
	mov dword [int_handler_addr], interrupt_handler
	mov dword [fat_cache_sector], 0xFFFFFFFF

	push ruler
	call putstr
	add esp, 4
	push test1
	push 0
	push 0
	call search_file
	mov dword [esp + 8], test2
	call search_file
	mov dword [esp + 8], test3
	call search_file
	mov dword [esp + 8], test4
	call search_file
	mov dword [esp + 8], test5
	call search_file
	mov dword [esp + 8], test6
	call search_file

exit:
	cli
stop_loop:
	hlt
	jmp stop_loop

ruler: db '"0123456789A"', 13, 10, 0
test1: db 'test.txt', 0
test2: db 'tesuto', 0
test3: db 'hogehogehoge.txt', 0
test4: db 'hoge.text', 0
test5: db '.abc', 0
test6: db 'ABC$!.tXt', 0

disk_init_ng_mes:
	db 'disk_init failed : ', 0

disk_read_ng_mes:
	db 'disk_read failed : ', 0

absolute 0x7C00
bpb_jmp_ope_code:        resb 3
bpb_oem_name:            resb 8
bpb_bytes_per_sector:    resw 1
bpb_sectors_per_cluster: resb 1
bpb_reserved_sectors:    resw 1
bpb_number_of_fats:      resb 1
bpb_root_entries:        resw 1
bpb_total_sectors:       resw 1
bpb_media_descriptor:    resb 1
bpb_sectors_per_fat:     resw 1
bpb_sectors_per_track:   resw 1
bpb_heads:               resw 1
bpb_hidden_sectors:      resd 1
bpb_big_total_sectors:   resd 1

absolute 0x8000

read_disk_buffer_addr:
	resb 0x200

si_eax: resd 1
si_ecx: resd 1
si_edx: resd 1
si_ebx: resd 1
si_esi: resd 1
si_edi: resd 1
si_esp: resd 1
si_ebp: resd 1
si_eflags: resd 1
si_cr3: resd 1
si_ino: resd 1
si_ds:  resw 1
si_es:  resw 1
si_ss:  resw 1
si_fs:  resw 1
si_gs:  resw 1
si_int_addr: resw 1
si_idt: resb 6
si_idt_zero: resb 6

int_handler_addr: resd 1

fat_cache_sector: resd 1
fat_cache: resb 0x200

search_file_buffer: resb 0x200
