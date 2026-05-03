    .syntax unified
    .cpu    cortex-m33
    .thumb

    /* ---------- GPIO + CMU (same as Session 7) ---------- */
    .equ CMU_CLKEN0,    0x40008064
    .equ CMU_GPIO_BIT,  (1 << 26)
    .equ GPIO_PC_BASE,  0x4003C090
    .equ PC_MODEL,      GPIO_PC_BASE + 0x04
    .equ PC_DOUT,       GPIO_PC_BASE + 0x10
    .equ LED_RED_BIT,   (1 << 1)

    /* ---------- SysTick ---------- */
    .equ SYST_CSR,      0xE000E010
    .equ SYST_RVR,      0xE000E014
    .equ SYST_CVR,      0xE000E018
    .equ SYST_CSR_VAL,  ((1 << 2) | (1 << 0))    @ CLKSOURCE=CPU, ENABLE=1
    .equ TICKS_PER_MS,  20000                    @ ~20 MHz core clock at reset

    /* ---------- Vector table ---------- */
    .section .vectors, "a", %progbits
    .word   __stack_top
    .word   reset_handler + 1

    /* ---------- Code ---------- */
    .section .text
    .thumb_func
    .global  reset_handler
reset_handler:
    /* Enable GPIO clock */
    ldr     r0, =CMU_CLKEN0
    ldr     r1, [r0]
    ldr     r2, =CMU_GPIO_BIT
    orr     r1, r1, r2
    str     r1, [r0]

    /* PC1 -> push-pull output */
    ldr     r0, =PC_MODEL
    ldr     r1, [r0]
    ldr     r2, =0xFFFFFF0F
    and     r1, r1, r2
    mov     r2, #0x40
    orr     r1, r1, r2
    str     r1, [r0]

    /* Cache LED state in r4 (DOUT addr), r5 (mask), r6 (DOUT value) */
    ldr     r4, =PC_DOUT
    ldr     r5, =LED_RED_BIT
    ldr     r6, [r4]

blink_loop:
    eor     r6, r6, r5
    str     r6, [r4]
    mov     r0, #500
    bl      delay_ms
    b       blink_loop


    /* delay_ms(uint32_t ms in r0): block for ~ms milliseconds using SysTick. */
    .thumb_func
    .global  delay_ms
delay_ms:
    /* Configure SysTick: 1 ms reload value */
    ldr     r1, =SYST_RVR
    ldr     r2, =(TICKS_PER_MS - 1)
    str     r2, [r1]

    ldr     r1, =SYST_CVR
    mov     r2, #0
    str     r2, [r1]                @ writing any value clears CVR + COUNTFLAG

    ldr     r1, =SYST_CSR
    ldr     r2, =SYST_CSR_VAL
    str     r2, [r1]                @ start counting

1:  /* Outer loop: 'r0' milliseconds left */
    cmp     r0, #0
    beq     3f
2:  /* Inner spin: wait for COUNTFLAG (bit 16 of CSR) to go high */
    ldr     r3, [r1]
    tst     r3, #(1 << 16)
    beq     2b
    subs    r0, r0, #1
    b       1b

3:  /* Disable SysTick */
    mov     r2, #0
    str     r2, [r1]
    bx      lr
