# Minimal Makefile for an ARM Cortex-M33 Thumb assembly program.
# Usage:
#   make           build main.elf and main.bin
#   make flash     flash main.bin to the Nano Matter via J-Link
#   make clean     remove build artefacts

PREFIX  := arm-none-eabi-
AS      := $(PREFIX)as
LD      := $(PREFIX)ld
OBJCOPY := $(PREFIX)objcopy
OBJDUMP := $(PREFIX)objdump

# J-Link device name for the Nano Matter's MGM240SD22VNA (EFR32MG24Bxxx, 1536kB flash).
JLINK_DEVICE ?= EFR32MG24BxxxF1536

ASFLAGS := -mcpu=cortex-m33 -mthumb -g
LDFLAGS := -T linker.ld --no-warn-rwx-segments

all: main.bin

main.o: main.s
	$(AS) $(ASFLAGS) $< -o $@

main.elf: main.o linker.ld
	$(LD) $(LDFLAGS) main.o -o $@

main.bin: main.elf
	$(OBJCOPY) -O binary $< $@

disasm: main.elf
	$(OBJDUMP) -d $<

flash: main.bin
	@echo "device $(JLINK_DEVICE)"          > flash.jlink
	@echo "si 1"                           >> flash.jlink
	@echo "speed 4000"                     >> flash.jlink
	@echo "connect"                        >> flash.jlink
	@echo "r"                              >> flash.jlink
	@echo "h"                              >> flash.jlink
	@echo "loadbin main.bin 0x08000000"    >> flash.jlink
	@echo "r"                              >> flash.jlink
	@echo "g"                              >> flash.jlink
	@echo "qc"                             >> flash.jlink
	JLinkExe -CommandFile flash.jlink
	@rm -f flash.jlink

clean:
	rm -f main.o main.elf main.bin flash.jlink

.PHONY: all clean flash disasm
