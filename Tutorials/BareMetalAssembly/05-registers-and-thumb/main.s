    .syntax unified
    .cpu    cortex-m33
    .thumb

    .section .vectors, "a", %progbits
    .word   __stack_top
    .word   reset_handler + 1

    .section .text
    .thumb_func
    .global  reset_handler
reset_handler:
    ldr     r0, =0x20000000     @ r0 = pointer to first word of RAM
    mov     r1, #7
    mov     r2, #11
    mov     r3, #23
    add     r1, r1, r2          @ r1 = 18
    add     r1, r1, r3          @ r1 = 41
    str     r1, [r0]            @ *0x20000000 = 41

1:  b       1b                  @ spin forever
