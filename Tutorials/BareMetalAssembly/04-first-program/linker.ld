/* Linker script for Arduino Nano Matter (EFR32MG24, 1536 kB Flash, 256 kB RAM) */

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
