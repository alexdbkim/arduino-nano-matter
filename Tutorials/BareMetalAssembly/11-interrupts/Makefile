# Minimal Makefile for an ARM Cortex-M33 Thumb assembly program.
# Usage:
#   make           build main.elf and main.bin
#   make flash     flash main.elf to the Nano Matter via the on-board CMSIS-DAP probe
#   make gdbserver run OpenOCD as a GDB server (port 3333) without flashing
#   make clean     remove build artefacts
#
# Prerequisites:
#   - arm-none-eabi-* toolchain (Homebrew: `brew install --cask gcc-arm-embedded`)
#   - the Silicon Labs Arduino core installed once via the Arduino IDE Boards
#     Manager (search "Silicon Labs"). That ships a forked OpenOCD with the
#     custom target/efm32s2_g23.cfg script needed to talk to the EFR32MG24's
#     flash. Vanilla Homebrew openocd 0.12 does NOT include this config and
#     will fail to program the chip even though it can connect.
#
# Override OPENOCD on the command line if you have it installed elsewhere.

PREFIX  := arm-none-eabi-
AS      := $(PREFIX)as
LD      := $(PREFIX)ld
OBJCOPY := $(PREFIX)objcopy
OBJDUMP := $(PREFIX)objdump

SILABS_OOCD ?= $(HOME)/Library/Arduino15/packages/SiliconLabs/tools/openocd/0.12.0-arduino1-static
OPENOCD     ?= $(SILABS_OOCD)/bin/openocd
OPENOCD_SCRIPTS ?= $(SILABS_OOCD)/share/openocd/scripts
OPENOCD_FLAGS   ?= -s $(OPENOCD_SCRIPTS) -f interface/cmsis-dap.cfg -f target/efm32s2_g23.cfg

ASFLAGS := -mcpu=cortex-m33 -mthumb -g
LDFLAGS := -T linker.ld --no-warn-rwx-segments

all: main.bin

main.o: main.s
	$(AS) $(ASFLAGS) $< -o $@

main.elf: main.o linker.ld
	$(LD) $(LDFLAGS) main.o -o $@

main.bin: main.elf
	$(OBJCOPY) -O binary $< $@

main.hex: main.elf
	$(OBJCOPY) -O ihex $< $@

disasm: main.elf
	$(OBJDUMP) -d $<

flash: main.hex
	$(OPENOCD) $(OPENOCD_FLAGS) -c "init; reset_config srst_nogate; reset halt; program $< verify; reset; exit"

gdbserver: main.elf
	$(OPENOCD) $(OPENOCD_FLAGS) -c "init; reset_config srst_nogate"

clean:
	rm -f main.o main.elf main.bin main.hex

.PHONY: all clean flash disasm gdbserver
