/* Linker script for Arduino Nano Matter (EFR32MG24, 1536 kB Flash, 256 kB RAM)
 *
 * Note on LENGTH: this is a link-time sanity check only. ld errors out if the
 * output sections exceed it. It does NOT change the binary, the bytes
 * programmed by `make flash`, or runtime behaviour. We use the full chip
 * sizes here so any program in this tutorial will link. Shrink LENGTH only
 * when you intentionally carve flash into regions (bootloader / app /
 * settings page), not as a way to "save space".
 */

ENTRY(reset_handler)

MEMORY
{
    FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 1536K
    RAM   (rwx): ORIGIN = 0x20000000, LENGTH = 256K
}

__stack_top = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS
{
    .vectors : { KEEP(*(.vectors)) } > FLASH
    .text    : { *(.text*) }         > FLASH
    .rodata  : { *(.rodata*) }       > FLASH

    /DISCARD/ : { *(.ARM.*) *(.note.*) *(.comment) }
}
