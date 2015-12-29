bits 16
org 0x0500

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
	or eax, 0x00000001 ; enable PE
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

	; switch to real mode
	lidt [si_idt_zero]
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
	jmp si_int_end
si_int_11:
	int 0x11
	jmp si_int_end
si_int_12:
	int 0x12
	jmp si_int_end
si_int_13:
	int 0x13
	jmp si_int_end
si_int_14:
	int 0x14
	jmp si_int_end
si_int_15:
	int 0x15
	jmp si_int_end
si_int_16:
	int 0x16
	jmp si_int_end
si_int_17:
	int 0x17
	jmp si_int_end
si_int_18:
	int 0x18
	jmp si_int_end
si_int_19:
	int 0x19
	jmp si_int_end
si_int_1A:
	int 0x1A
	jmp si_int_end
si_int_end:
	cli
	; save registers which may contain return values from BIOS
	mov [si_eax], ax
	mov [si_ecx], cx
	mov [si_edx], dx
	mov [si_ebx], bx
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
	mov ax, 32
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax

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

align 4
si_eax: dd 0
si_ecx: dd 0
si_edx: dd 0
si_ebx: dd 0
si_esi: dd 0
si_edi: dd 0
si_esp: dd 0
si_ebp: dd 0
si_eflags: dd 0
si_ino: dd 0
si_ds:  dw 0
si_es:  dw 0
si_ss:  dw 0
si_fs:  dw 0
si_gs:  dw 0
si_int_addr: dw 0
si_idt: times 6 db 0
si_idt_zero: dw 0x0400, 0, 0

bits 32
pstart:
	mov ax, 16
	mov ss, ax
	mov ds, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax
	mov esp, 0xFFF0

	mov ax, 0x0003
	push 0x10
	call soft_int ; initialize screen

	mov ah, 0x02
	xor bh, bh
	xor dx, dx
	push 0x10
	call soft_int ; move cursor to (0, 0)
	
	mov ah, 0x0E
	mov esi, str
puts_loop:
	mov al, [esi]
	test al, al
	jz puts_end
	push 0x10
	call soft_int
	inc esi
	jmp puts_loop
puts_end:

waitkey_loop:
	mov ah, 0x01
	push 0x16
	call soft_int
	jz waitkey_loop

	mov ax, 0x0E21
	xor bx, bx
	push 0x10
	call soft_int

	cli
stop_loop:
	hlt
	jmp stop_loop

str:
	db 'hello, world!', 13, 10
	db 'from protected mode!', 13, 10
	db 0
