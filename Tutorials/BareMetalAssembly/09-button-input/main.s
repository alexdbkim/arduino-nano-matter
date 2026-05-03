    .syntax unified
    .cpu    cortex-m33
    .thumb

    .equ CMU_CLKEN0,    0x40008064
    .equ CMU_GPIO_BIT,  (1 << 26)

    .equ GPIO_PA_BASE,  0x4003C030
    .equ PA_MODEL,      GPIO_PA_BASE + 0x04
    .equ PA_DOUT,       GPIO_PA_BASE + 0x10
    .equ PA_DIN,        GPIO_PA_BASE + 0x14

    .equ GPIO_PC_BASE,  0x4003C090
    .equ PC_MODEL,      GPIO_PC_BASE + 0x04
    .equ PC_DOUT,       GPIO_PC_BASE + 0x10

    .equ LED_RED_BIT,   (1 << 1)        @ PC1
    .equ BTN_BIT,       (1 << 0)        @ PA0

    .section .vectors, "a", %progbits
    .word   __stack_top
    .word   reset_handler + 1

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

    /* PC1 -> push-pull output (mode 0x4 in MODEL[7:4]) */
    ldr     r0, =PC_MODEL
    ldr     r1, [r0]
    ldr     r2, =0xFFFFFF0F
    and     r1, r1, r2
    mov     r2, #0x40
    orr     r1, r1, r2
    str     r1, [r0]

    /* PA0 -> INPUTPULL (mode 0x3 in MODEL[3:0]) */
    ldr     r0, =PA_MODEL
    ldr     r1, [r0]
    ldr     r2, =0xFFFFFFF0
    and     r1, r1, r2
    mov     r2, #0x3
    orr     r1, r1, r2
    str     r1, [r0]

    /* PA0 DOUT bit 0 = 1 -> select pull-up */
    ldr     r0, =PA_DOUT
    ldr     r1, [r0]
    orr     r1, r1, #BTN_BIT
    str     r1, [r0]

    /* Pre-load constants used in the loop */
    ldr     r4, =PA_DIN
    ldr     r5, =PC_DOUT

poll_loop:
    /* Read button: bit 0 of PA_DIN */
    ldr     r0, [r4]
    tst     r0, #BTN_BIT
    beq     pressed

    /* Released: turn LED OFF (set PC1 high) */
    ldr     r1, [r5]
    orr     r1, r1, #LED_RED_BIT
    str     r1, [r5]
    b       poll_loop

pressed:
    /* Pressed: turn LED ON (clear PC1) */
    ldr     r1, [r5]
    bic     r1, r1, #LED_RED_BIT
    str     r1, [r5]
    b       poll_loop
