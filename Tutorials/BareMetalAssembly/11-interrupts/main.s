    .syntax unified
    .cpu    cortex-m33
    .thumb

    /* ============================================================
     * Equates
     * ============================================================ */
    .equ CMU_CLKEN0,        0x40008064
    .equ CMU_GPIO_BIT,      (1 << 26)

    .equ GPIO_BASE,         0x4003C000
    .equ GPIO_PA_BASE,      GPIO_BASE + 0x30
    .equ GPIO_PC_BASE,      GPIO_BASE + 0x90
    .equ PA_MODEL,          GPIO_PA_BASE + 0x04
    .equ PA_DOUT,           GPIO_PA_BASE + 0x10
    .equ PC_MODEL,          GPIO_PC_BASE + 0x04
    .equ PC_DOUT,           GPIO_PC_BASE + 0x10

    .equ GPIO_EXTIPSELL,    GPIO_BASE + 0x400
    .equ GPIO_EXTIPINSELL,  GPIO_BASE + 0x408
    .equ GPIO_EXTIFALL,     GPIO_BASE + 0x414
    .equ GPIO_IF,           GPIO_BASE + 0x420
    .equ GPIO_IEN,          GPIO_BASE + 0x424

    .equ NVIC_ISER0,        0xE000E100
    .equ GPIO_EVEN_IRQn,    26

    .equ SYST_CSR,          0xE000E010
    .equ SYST_RVR,          0xE000E014
    .equ SYST_CVR,          0xE000E018
    /* CSR: CLKSOURCE=CPU(2) | TICKINT(1) | ENABLE(0) */
    .equ SYST_CSR_VAL,      ((1 << 2) | (1 << 1) | (1 << 0))
    .equ SYST_RELOAD,       (5000000 - 1)       @ ~250 ms at 20 MHz

    .equ LED_R,             (1 << 1)            @ PC1
    .equ LED_G,             (1 << 2)            @ PC2
    .equ LED_B,             (1 << 3)            @ PC3
    .equ LED_ALL,           (LED_R | LED_G | LED_B)

    /* Where we store the currently-active LED mask in RAM. */
    .equ ACTIVE_MASK_ADDR,  0x20000000

    /* ============================================================
     * Vector table
     * Entries 0..1 are SP + reset. Entry 15 is SysTick. Entry 42
     * (= 16 + 26) is GPIO_EVEN. Everything else points at
     * default_handler so stray interrupts are at least debuggable.
     * ============================================================ */
    .section .vectors, "a", %progbits
    .word   __stack_top                         @  0: initial SP
    .word   reset_handler + 1                   @  1: Reset
    .word   default_handler + 1                 @  2: NMI
    .word   default_handler + 1                 @  3: HardFault
    .word   default_handler + 1                 @  4: MemManage
    .word   default_handler + 1                 @  5: BusFault
    .word   default_handler + 1                 @  6: UsageFault
    .word   default_handler + 1                 @  7: SecureFault
    .word   0                                   @  8: Reserved
    .word   0                                   @  9
    .word   0                                   @ 10
    .word   default_handler + 1                 @ 11: SVCall
    .word   default_handler + 1                 @ 12: DebugMonitor
    .word   0                                   @ 13: Reserved
    .word   default_handler + 1                 @ 14: PendSV
    .word   systick_handler + 1                 @ 15: SysTick
    /* Peripheral IRQs.
     * IRQs 0..24 unused; IRQ 25 = GPIO_ODD (unused); IRQ 26 = GPIO_EVEN.
     * That's 25 + 1 = 26 default entries, then gpio_even_handler. */
    .rept   26
    .word   default_handler + 1                 @ IRQs 0..25 (incl. GPIO_ODD)
    .endr
    .word   gpio_even_handler + 1               @ IRQ 26: GPIO_EVEN
    .rept   8
    .word   default_handler + 1
    .endr

    /* ============================================================
     * Code
     * ============================================================ */
    .section .text

    /* -------- default handler: spin so a debugger can find us -- */
    .thumb_func
    .global  default_handler
default_handler:
    b       default_handler

    /* -------- reset_handler ------------------------------------ */
    .thumb_func
    .global  reset_handler
reset_handler:
    /* Initialise active_mask = LED_R (start blinking red). */
    ldr     r0, =ACTIVE_MASK_ADDR
    mov     r1, #LED_R
    str     r1, [r0]

    /* Enable GPIO clock */
    ldr     r0, =CMU_CLKEN0
    ldr     r1, [r0]
    ldr     r2, =CMU_GPIO_BIT
    orr     r1, r1, r2
    str     r1, [r0]

    /* PC1, PC2, PC3 -> push-pull (mode 4 each).
     * MODEL[15:4] gets 0x444 (pins 1,2,3) ; clear the existing field first. */
    ldr     r0, =PC_MODEL
    ldr     r1, [r0]
    ldr     r2, =0xFFFF000F             @ keep pin 0, clear pins 1..3
    and     r1, r1, r2
    ldr     r2, =0x00004440             @ mode 4 in slots 1,2,3
    orr     r1, r1, r2
    str     r1, [r0]

    /* All LEDs off (active low -> set bits 1,2,3 in DOUT) */
    ldr     r0, =PC_DOUT
    ldr     r1, [r0]
    orr     r1, r1, #LED_ALL
    str     r1, [r0]

    /* PA0 -> INPUTPULL (mode 0x3) */
    ldr     r0, =PA_MODEL
    ldr     r1, [r0]
    ldr     r2, =0xFFFFFFF0
    and     r1, r1, r2
    mov     r2, #0x3
    orr     r1, r1, r2
    str     r1, [r0]

    /* PA0 DOUT bit 0 = 1 -> pull-up */
    ldr     r0, =PA_DOUT
    ldr     r1, [r0]
    orr     r1, r1, #1
    str     r1, [r0]

    /* GPIO EXTI channel 0: PORTA, PIN0, falling edge.
     * EXTIPSELL[1:0]=0 (PORTA), EXTIPINSELL[1:0]=0 (PIN0).
     * Both are zero by default after reset, but be explicit. */
    ldr     r0, =GPIO_EXTIPSELL
    ldr     r1, [r0]
    ldr     r2, =0xFFFFFFFC
    and     r1, r1, r2
    str     r1, [r0]

    ldr     r0, =GPIO_EXTIPINSELL
    ldr     r1, [r0]
    and     r1, r1, r2
    str     r1, [r0]

    /* Falling edge enable for channel 0 */
    ldr     r0, =GPIO_EXTIFALL
    ldr     r1, [r0]
    orr     r1, r1, #1
    str     r1, [r0]

    /* Clear any stale interrupt flag for channel 0 */
    ldr     r0, =GPIO_IF
    mov     r1, #1
    str     r1, [r0]

    /* Enable channel 0 in GPIO_IEN */
    ldr     r0, =GPIO_IEN
    ldr     r1, [r0]
    orr     r1, r1, #1
    str     r1, [r0]

    /* Enable GPIO_EVEN_IRQn (26) in the NVIC */
    ldr     r0, =NVIC_ISER0
    mov     r1, #1
    lsl     r1, r1, #GPIO_EVEN_IRQn
    str     r1, [r0]

    /* Configure SysTick with TICKINT = 1 */
    ldr     r0, =SYST_RVR
    ldr     r1, =SYST_RELOAD
    str     r1, [r0]
    ldr     r0, =SYST_CVR
    mov     r1, #0
    str     r1, [r0]
    ldr     r0, =SYST_CSR
    ldr     r1, =SYST_CSR_VAL
    str     r1, [r0]

idle_loop:
    wfi                                 @ sleep until next interrupt
    b       idle_loop

    /* -------- systick_handler ---------------------------------- */
    /* Toggle whichever bit is currently active. */
    .thumb_func
    .global  systick_handler
systick_handler:
    ldr     r0, =ACTIVE_MASK_ADDR
    ldr     r1, [r0]                    @ active_mask
    ldr     r2, =PC_DOUT
    ldr     r3, [r2]
    eor     r3, r3, r1
    str     r3, [r2]
    bx      lr

    /* -------- gpio_even_handler -------------------------------- */
    /* Clear flag, turn all LEDs off, rotate active mask R->G->B. */
    .thumb_func
    .global  gpio_even_handler
gpio_even_handler:
    /* Clear GPIO interrupt flag for channel 0 (write 1 to clear) */
    ldr     r0, =GPIO_IF
    mov     r1, #1
    str     r1, [r0]

    /* Turn all LEDs off */
    ldr     r0, =PC_DOUT
    ldr     r1, [r0]
    orr     r1, r1, #LED_ALL
    str     r1, [r0]

    /* Rotate active mask: R(2) -> G(4) -> B(8) -> R */
    ldr     r0, =ACTIVE_MASK_ADDR
    ldr     r1, [r0]
    cmp     r1, #LED_B
    beq     1f
    lsl     r1, r1, #1                  @ shift left -> next colour
    b       2f
1:  mov     r1, #LED_R                  @ wrap blue -> red
2:  str     r1, [r0]
    bx      lr
