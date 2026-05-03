    .syntax unified
    .cpu    cortex-m33
    .thumb

    /* ---------- Equates ---------- */
    .equ CMU_CLKEN0,    0x40008064
    .equ CMU_GPIO_BIT,  (1 << 26)

    .equ GPIO_PC_BASE,  0x4003C090
    .equ PC_MODEL,      GPIO_PC_BASE + 0x04
    .equ PC_DOUT,       GPIO_PC_BASE + 0x10
    .equ LED_RED_BIT,   (1 << 1)

    .equ SYST_CSR,      0xE000E010
    .equ SYST_RVR,      0xE000E014
    .equ SYST_CVR,      0xE000E018
    .equ SYST_CSR_VAL,  ((1 << 2) | (1 << 0))
    .equ TICKS_PER_MS,  20000

    /* ---------- Vector table ---------- */
    .section .vectors, "a", %progbits
    .word   __stack_top
    .word   reset_handler + 1

    /* ---------- Code ---------- */
    .section .text

    .thumb_func
    .global  reset_handler
reset_handler:
    bl      led_init

main_loop:
    bl      led_on
    mov     r0, #500
    bl      delay_ms
    bl      led_off
    mov     r0, #500
    bl      delay_ms
    b       main_loop

    /* ---------------------------------------------------------------- */
    /* led_init: enable GPIO clock and configure PC1 as push-pull.       */
    /* Uses only r0-r2 (caller-saved).                                  */
    /* ---------------------------------------------------------------- */
    .thumb_func
led_init:
    ldr     r0, =CMU_CLKEN0
    ldr     r1, [r0]
    ldr     r2, =CMU_GPIO_BIT
    orr     r1, r1, r2
    str     r1, [r0]

    ldr     r0, =PC_MODEL
    ldr     r1, [r0]
    ldr     r2, =0xFFFFFF0F
    and     r1, r1, r2
    mov     r2, #0x40
    orr     r1, r1, r2
    str     r1, [r0]
    bx      lr

    /* led_on: clear PC1 in DOUT (LEDs are active low) */
    .thumb_func
led_on:
    ldr     r0, =PC_DOUT
    ldr     r1, [r0]
    bic     r1, r1, #LED_RED_BIT
    str     r1, [r0]
    bx      lr

    /* led_off: set PC1 in DOUT */
    .thumb_func
led_off:
    ldr     r0, =PC_DOUT
    ldr     r1, [r0]
    orr     r1, r1, #LED_RED_BIT
    str     r1, [r0]
    bx      lr

    /* ---------------------------------------------------------------- */
    /* delay_ms(uint32_t ms in r0): block ms milliseconds via SysTick.  */
    /* Uses r4 and lr -> must save/restore.                              */
    /* ---------------------------------------------------------------- */
    .thumb_func
    .global  delay_ms
delay_ms:
    push    {r4, lr}
    mov     r4, r0                  @ r4 = ms remaining

    ldr     r1, =SYST_RVR
    ldr     r2, =(TICKS_PER_MS - 1)
    str     r2, [r1]
    ldr     r1, =SYST_CVR
    mov     r2, #0
    str     r2, [r1]
    ldr     r1, =SYST_CSR
    ldr     r2, =SYST_CSR_VAL
    str     r2, [r1]

1:  cmp     r4, #0
    beq     3f
2:  ldr     r3, [r1]                @ read CSR
    tst     r3, #(1 << 16)          @ COUNTFLAG?
    beq     2b
    subs    r4, r4, #1
    b       1b

3:  mov     r2, #0
    str     r2, [r1]                @ disable SysTick
    pop     {r4, pc}
