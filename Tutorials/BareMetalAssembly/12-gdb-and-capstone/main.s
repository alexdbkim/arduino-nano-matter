    .syntax unified
    .cpu    cortex-m33
    .thumb

    /* ============================================================
     * Capstone: interrupt-driven RGB blinker.
     * SysTick (2 Hz)  -> toggle the active LED bit
     * Button press    -> rotate active LED:
     *                       red -> green -> blue -> all-off -> red ...
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
    .equ SYST_CSR_VAL,      ((1 << 2) | (1 << 1) | (1 << 0))
    .equ SYST_RELOAD,       (5000000 - 1)

    .equ LED_R,             (1 << 1)
    .equ LED_G,             (1 << 2)
    .equ LED_B,             (1 << 3)
    .equ LED_ALL,           (LED_R | LED_G | LED_B)

    /* RAM layout (no .bss section in this minimal program) */
    .equ ACTIVE_MASK_ADDR,  0x20000000      @ uint32: active LED bit (0 = none)
    .equ PRESS_COUNT_ADDR,  0x20000004      @ uint32: total presses

    /* ============================================================
     * Vector table
     * ============================================================ */
    .section .vectors, "a", %progbits
    .word   __stack_top
    .word   reset_handler + 1
    .word   default_handler + 1     @  2: NMI
    .word   default_handler + 1     @  3: HardFault
    .word   default_handler + 1     @  4: MemManage
    .word   default_handler + 1     @  5: BusFault
    .word   default_handler + 1     @  6: UsageFault
    .word   default_handler + 1     @  7: SecureFault
    .word   0, 0, 0
    .word   default_handler + 1     @ 11: SVCall
    .word   default_handler + 1     @ 12: DebugMonitor
    .word   0
    .word   default_handler + 1     @ 14: PendSV
    .word   systick_handler + 1     @ 15: SysTick
    .rept   26
    .word   default_handler + 1     @ IRQs 0..25
    .endr
    .word   gpio_even_handler + 1   @ IRQ 26: GPIO_EVEN
    .rept   8
    .word   default_handler + 1
    .endr

    /* ============================================================
     * Code
     * ============================================================ */
    .section .text

    .thumb_func
    .global default_handler
default_handler:
    b       default_handler

    .thumb_func
    .global reset_handler
reset_handler:
    /* Initialise RAM state */
    ldr     r0, =ACTIVE_MASK_ADDR
    mov     r1, #LED_R
    str     r1, [r0]
    ldr     r0, =PRESS_COUNT_ADDR
    mov     r1, #0
    str     r1, [r0]

    /* Enable GPIO clock */
    ldr     r0, =CMU_CLKEN0
    ldr     r1, [r0]
    ldr     r2, =CMU_GPIO_BIT
    orr     r1, r1, r2
    str     r1, [r0]

    /* PC1/PC2/PC3 push-pull */
    ldr     r0, =PC_MODEL
    ldr     r1, [r0]
    ldr     r2, =0xFFFF000F
    and     r1, r1, r2
    ldr     r2, =0x00004440
    orr     r1, r1, r2
    str     r1, [r0]

    /* All LEDs off */
    ldr     r0, =PC_DOUT
    ldr     r1, [r0]
    orr     r1, r1, #LED_ALL
    str     r1, [r0]

    /* PA0 INPUTPULL with pull-up */
    ldr     r0, =PA_MODEL
    ldr     r1, [r0]
    ldr     r2, =0xFFFFFFF0
    and     r1, r1, r2
    mov     r2, #0x3
    orr     r1, r1, r2
    str     r1, [r0]
    ldr     r0, =PA_DOUT
    ldr     r1, [r0]
    orr     r1, r1, #1
    str     r1, [r0]

    /* GPIO EXTI 0 -> PORTA pin 0 falling edge */
    ldr     r0, =GPIO_EXTIPSELL
    ldr     r1, [r0]
    ldr     r2, =0xFFFFFFFC
    and     r1, r1, r2
    str     r1, [r0]
    ldr     r0, =GPIO_EXTIPINSELL
    ldr     r1, [r0]
    and     r1, r1, r2
    str     r1, [r0]
    ldr     r0, =GPIO_EXTIFALL
    ldr     r1, [r0]
    orr     r1, r1, #1
    str     r1, [r0]
    ldr     r0, =GPIO_IF
    mov     r1, #1
    str     r1, [r0]
    ldr     r0, =GPIO_IEN
    ldr     r1, [r0]
    orr     r1, r1, #1
    str     r1, [r0]

    /* NVIC: enable GPIO_EVEN_IRQn (26) */
    ldr     r0, =NVIC_ISER0
    mov     r1, #1
    lsl     r1, r1, #GPIO_EVEN_IRQn
    str     r1, [r0]

    /* SysTick (CPU clock, IRQ enabled) */
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
    wfi
    b       idle_loop

    /* SysTick handler: toggle the active LED bit (no-op when mask = 0). */
    .thumb_func
    .global systick_handler
systick_handler:
    ldr     r0, =ACTIVE_MASK_ADDR
    ldr     r1, [r0]
    cmp     r1, #0
    beq     1f                          @ all-off: do nothing
    ldr     r2, =PC_DOUT
    ldr     r3, [r2]
    eor     r3, r3, r1
    str     r3, [r2]
1:  bx      lr

    /* GPIO_EVEN handler: clear flag, increment counter, advance state.
     * State machine: LED_R -> LED_G -> LED_B -> 0 (all off) -> LED_R ...
     */
    .thumb_func
    .global gpio_even_handler
gpio_even_handler:
    /* Clear the GPIO interrupt flag for channel 0 */
    ldr     r0, =GPIO_IF
    mov     r1, #1
    str     r1, [r0]

    /* press_count++ */
    ldr     r0, =PRESS_COUNT_ADDR
    ldr     r1, [r0]
    add     r1, r1, #1
    str     r1, [r0]

    /* Force all LEDs off so we don't leave the previous one stuck on */
    ldr     r0, =PC_DOUT
    ldr     r1, [r0]
    orr     r1, r1, #LED_ALL
    str     r1, [r0]

    /* Advance the active mask through R -> G -> B -> 0 -> R */
    ldr     r0, =ACTIVE_MASK_ADDR
    ldr     r1, [r0]
    cmp     r1, #0
    beq     to_red
    cmp     r1, #LED_B
    beq     to_off
    /* otherwise shift left (R->G or G->B) */
    lsl     r1, r1, #1
    b       store_state
to_red:
    mov     r1, #LED_R
    b       store_state
to_off:
    mov     r1, #0
store_state:
    str     r1, [r0]
    bx      lr
