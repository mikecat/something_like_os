.PHONY: all
all: mbr bpb

.PHONY: mbr
mbr: mbr.bin mbr-disasm.txt

mbr.bin: mbr.asm
	nasm -w+all -o mbr.bin mbr.asm

mbr-disasm.txt: mbr.bin
	objdump -D -b binary -m i8086 mbr.bin > mbr-disasm.txt

.PHONY: bpb
bpb: bpb.bin bpb-disasm.txt

bpb.bin: bpb.asm
	nasm -w+all -o bpb.bin bpb.asm

bpb-disasm.txt: bpb.bin
	objdump -D -b binary -m i8086 bpb.bin > bpb-disasm.txt

plainhdd.img: plainhdd.asm
	nasm -o plainhdd.img plainhdd.asm

.PHONY: writembr
writembr: mbr
	dd bs=1 conv=notrunc count=446 if=mbr.bin of=hdd.img
	dd bs=1 conv=notrunc count=2 skip=510 seek=510 if=mbr.bin of=hdd.img

.PHONY: writebpb
writebpb: bpb
	dd bs=1 conv=notrunc count=450 skip=62 seek=8773694 if=bpb.bin of=hdd.img
