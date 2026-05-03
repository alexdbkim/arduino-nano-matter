    .syntax unified
    .cpu    cortex-m33
    .thumb

    /* ------------------------------------------------------------------
     * Vector table — placed at 0x08000000 by the linker script.
     * Only the first two entries matter for this minimal program.
     * ------------------------------------------------------------------ */
    .section .vectors, "a", %progbits
    .word   __stack_top         /* 0x00: initial SP                     */
    .word   reset_handler + 1   /* 0x04: reset handler (Thumb bit set)  */

    /* ------------------------------------------------------------------
     * Reset handler — the first instructions the CPU runs after reset.
     * Just loop forever. The chip is now executing OUR code.
     * ------------------------------------------------------------------ */
    .section .text
    .thumb_func
    .global  reset_handler
reset_handler:
    b       reset_handler
