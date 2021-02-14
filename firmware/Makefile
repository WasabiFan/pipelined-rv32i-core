#

include ./site-config.sh

all: firmware_text.hex firmware_data.hex

CC=$(RISCV_PREFIX)-gcc
AS=$(RISCV_PREFIX)-as
LD=$(RISCV_PREFIX)-ld
OBJCOPY=$(RISCV_PREFIX)-objcopy

SSFLAGS=-march=rv32i
CCFLAGS=-O1 -march=rv32i -mabi=ilp32 -Wno-builtin-declaration-mismatch -I./
LDFLAGS=-m elf32lriscv --script ld.script
LDPOSTFLAGS= -L./libmc -lmc -L$(RISCV_LIB) -lgcc

SOURCE_S=start.s
SOURCE_C=main.c

.c.o:
	$(CC) $(CCFLAGS) -c $*.c

.s.o:
	$(AS) $(SSFLAGS) -c $*.s -o $*.o

firmware.elf: $(SOURCE_S:.s=.o) $(SOURCE_C:.c=.o)
	@echo $(RISCV_LIB)
	$(LD) $(LDFLAGS) -o firmware.elf $(SOURCE_S:.s=.o) $(SOURCE_C:.c=.o) $(LDPOSTFLAGS)

firmware.img: firmware.elf
	$(OBJCOPY) -O binary $< $@

firmware_text.hex: firmware.img
	python3 img_to_hex.py 0x00000 0x10000 $< $@

firmware_data.hex: firmware.img
	python3 img_to_hex.py 0x10000 0x20000 $< $@

clean:
	rm -f *.o *.hex firmware.elf firmware.img firmware_text.hex firmware_data.hex 
