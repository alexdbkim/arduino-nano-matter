    .syntax unified
    .cpu    cortex-m33
    .thumb

    .equ CMU_CLKEN0,        0x40008064
    .equ CMU_CLKEN0_GPIO,   (1 << 26)

    .section .vectors, "a", %progbits
    .word   __stack_top
    .word   reset_handler + 1

    .section .text
    .thumb_func
    .global  reset_handler
reset_handler:
    /* Enable the GPIO clock by setting CMU_CLKEN0[26]. */
    ldr     r0, =CMU_CLKEN0         @ r0 = address of CMU_CLKEN0
    ldr     r1, [r0]                @ r1 = *CMU_CLKEN0
    movw    r2, #:lower16:CMU_CLKEN0_GPIO
    movt    r2, #:upper16:CMU_CLKEN0_GPIO
    orr     r1, r1, r2              @ set bit 26
    str     r1, [r0]                @ write back

1:  b       1b
