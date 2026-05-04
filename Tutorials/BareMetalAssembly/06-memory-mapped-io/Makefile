# Minimal Makefile for an ARM Cortex-M33 Thumb assembly program.
# Usage:
#   make           build main.elf and main.bin
#   make flash     flash main.elf to the Nano Matter via the on-board CMSIS-DAP probe
#   make gdbserver run OpenOCD as a GDB server (port 3333) without flashing
#   make clean     remove build artefacts
#
# Prerequisites: arm-none-eabi-* toolchain and openocd (Homebrew: `brew install open-ocd`).

PREFIX  := arm-none-eabi-
AS      := $(PREFIX)as
LD      := $(PREFIX)ld
OBJCOPY := $(PREFIX)objcopy
OBJDUMP := $(PREFIX)objdump

# OpenOCD config for the Nano Matter:
#   - the on-board ATSAMD11 USB bridge speaks CMSIS-DAP,
#   - EFR32MG24 is part of the EFM32 Series-2 target family.
# If your OpenOCD is older and lacks `target/efm32s2.cfg`, fall back to `target/efm32.cfg`.
OPENOCD       ?= openocd
OPENOCD_FLAGS ?= -f interface/cmsis-dap.cfg -f target/efm32s2.cfg

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

flash: main.elf
$(OPENOCD) $(OPENOCD_FLAGS) -c "program $< verify reset exit"

gdbserver: main.elf
$(OPENOCD) $(OPENOCD_FLAGS)

clean:
rm -f main.o main.elf main.bin

.PHONY: all clean flash disasm gdbserver
