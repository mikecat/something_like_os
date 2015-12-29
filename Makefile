IMG=hdd.img
IMGDIR=imagegen
LOADERDIR=loader

.PHONY: dummy
dummy:

.PHONY: mbr
mbr: $(LOADERDIR)/mbr.bin $(LOADERDIR)/mbr-disasm.txt

$(LOADERDIR)/mbr.bin: $(LOADERDIR)/mbr.asm
	nasm -w+all -o $(LOADERDIR)/mbr.bin $(LOADERDIR)/mbr.asm

$(LOADERDIR)/mbr-disasm.txt: $(LOADERDIR)/mbr.bin
	objdump -D -b binary -m i8086 $(LOADERDIR)/mbr.bin > $(LOADERDIR)/mbr-disasm.txt

.PHONY: bpb
bpb: $(LOADERDIR)/bpb.bin $(LOADERDIR)/bpb-disasm.txt

$(LOADERDIR)/bpb.bin: $(LOADERDIR)/bpb.asm
	nasm -w+all -o $(LOADERDIR)/bpb.bin $(LOADERDIR)/bpb.asm

$(LOADERDIR)/bpb-disasm.txt: $(LOADERDIR)/bpb.bin
	objdump -D -b binary -m i8086 $(LOADERDIR)/bpb.bin > $(LOADERDIR)/bpb-disasm.txt

$(IMGDIR)/plainhdd.img: $(IMGDIR)/plainhdd.asm
	nasm -o $(IMGDIR)/plainhdd.img $(IMGDIR)/plainhdd.asm

.PHONY: writembr
writembr: mbr
	dd bs=1 conv=notrunc count=446 if=$(LOADERDIR)/mbr.bin of=hdd.img
	dd bs=1 conv=notrunc count=2 skip=510 seek=510 if=$(LOADERDIR)/mbr.bin of=$(IMG)

.PHONY: writebpb
writebpb: bpb
	dd bs=1 conv=notrunc count=450 skip=62 seek=8773694 if=$(LOADERDIR)/bpb.bin of=$(IMG)
