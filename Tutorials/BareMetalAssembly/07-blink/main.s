    .syntax unified
    .cpu    cortex-m33
    .thumb

    /* ---------- Register addresses ---------- */
    .equ CMU_CLKEN0,    0x40008064
    .equ CMU_GPIO_BIT,  (1 << 26)

    .equ GPIO_PC_BASE,  0x4003C090      @ Port C register block
    .equ PC_MODEL,      GPIO_PC_BASE + 0x04
    .equ PC_DOUT,       GPIO_PC_BASE + 0x10

    .equ LED_RED_BIT,   (1 << 1)        @ PC1 = on-board red LED

    /* ---------- Vector table ---------- */
    .section .vectors, "a", %progbits
    .word   __stack_top
    .word   reset_handler + 1

    /* ---------- Code ---------- */
    .section .text
    .thumb_func
    .global  reset_handler
reset_handler:
    /* 1) Enable GPIO peripheral clock: CMU_CLKEN0 |= (1 << 26) */
    ldr     r0, =CMU_CLKEN0
    ldr     r1, [r0]
    ldr     r2, =CMU_GPIO_BIT
    orr     r1, r1, r2
    str     r1, [r0]

    /* 2) Configure PC1 as push-pull output:
     *    MODEL = (MODEL & ~0xF0) | (0x4 << 4)
     */
    ldr     r0, =PC_MODEL
    ldr     r1, [r0]
    ldr     r2, =0xFFFFFF0F     @ mask: clear bits [7:4]
    and     r1, r1, r2
    mov     r2, #0x40           @ mode 4 (PUSHPULL) for pin 1
    orr     r1, r1, r2
    str     r1, [r0]

    /* 3) Blink loop: toggle PC1 every ~half-second */
    ldr     r4, =PC_DOUT
    ldr     r5, =LED_RED_BIT

blink_loop:
    /* DOUT ^= LED_RED_BIT  (toggle the LED) */
    ldr     r6, [r4]
    eor     r6, r6, r5
    str     r6, [r4]

    /* Crude busy-wait delay. */
    ldr     r7, =1000000
delay_loop:
    subs    r7, r7, #1
    bne     delay_loop

    b       blink_loop
