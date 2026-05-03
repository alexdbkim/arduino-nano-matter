# Session 11 — Interrupts

> **Goal:** kill all polling. Make the LED blink because of a **SysTick interrupt**, and change colour because of a **GPIO interrupt** when you press the button.

This is the biggest conceptual jump in the series. Once you've done this once, you've done it forever — the pattern is the same for every chip and every peripheral.

---

## What's an interrupt?

Until now our `reset_handler` had to do everything itself — toggle the LED, count time, check the button. With **interrupts**, we tell the chip:

> "When something interesting happens (a timer ticks, a button is pressed), pause whatever you're doing, run my handler, then resume."

The CPU does this automatically — **without** us having to poll. The "interesting things" are wired up via:

- The **NVIC** (Nested Vectored Interrupt Controller) — the gatekeeper that decides which interrupts are enabled and at what priority.
- The **vector table** — the list of handler addresses we set up in Session 3.

When interrupt #N fires:

1. The CPU finishes the current instruction.
2. It pushes 8 registers (`r0`–`r3`, `r12`, `lr`, `pc`, `xPSR`) onto the stack — the so-called "exception stack frame". (Hardware does this for us. 🎉)
3. It loads `lr` with a special "EXC_RETURN" magic value.
4. It jumps to the handler address from vector table entry `16 + N`.
5. When the handler executes `bx lr`, the magic value triggers the CPU to pop the saved registers and resume the interrupted code.

So as far as our handler code is concerned, it's just a function. We `push`/`pop` callee-saved registers like any other function and end with `bx lr`.

> **Jargon:** The **NVIC** sits inside the Cortex-M core. Its registers live at `0xE000E100` and up. We only need one for now: **`NVIC_ISER0`** at `0xE000E100` — the "Interrupt Set-Enable Register 0". Setting bit `n` enables peripheral IRQ `n`.

---

## What we'll wire up

Two interrupt sources:

### 1. SysTick → blinks the active LED at ~2 Hz

Same SysTick from Session 8, but instead of polling `COUNTFLAG` we set bit 1 (`TICKINT`) in `SYST_CSR`. Now every time the counter wraps, the SysTick **exception** fires and our `systick_handler` runs.

The handler reads a one-word state in RAM (`active_mask`) that says "which LED bit is active right now", and XORs that bit in `PC_DOUT`.

### 2. GPIO_EVEN → cycles the active LED on every button press

The EFR32xG24 GPIO has 16 external-interrupt channels (EXTI 0–15). We use channel 0 and route it to **PA0** (the user button), triggering on a **falling edge** (press).

Three things to set up:

1. `GPIO_EXTIPSELL[1:0] = 0x0` → channel 0 watches **Port A**.
2. `GPIO_EXTIPINSELL[1:0] = 0x0` → channel 0 watches **pin 0** of that port.
3. `GPIO_EXTIFALL[0] = 1` → trigger on falling edge.
4. `GPIO_IEN[0] = 1` → enable channel 0's interrupt at the GPIO level.
5. `NVIC_ISER0 |= (1 << 26)` → enable the **`GPIO_EVEN_IRQn`** line in the NVIC. (Even-numbered EXTI channels go through `GPIO_EVEN_IRQn = 26`; odd-numbered through `GPIO_ODD_IRQn = 25`.)

Inside the handler, **always** clear the interrupt flag — write the bit back to `GPIO_IF` — or the handler will fire forever.

---

## The vector table grows up

Up to now our `.vectors` section had two words (SP + reset). Real interrupts need more:

```
index   offset   purpose
   0    0x000    initial SP
   1    0x004    reset_handler
   2-14 0x008    system handlers (NMI, HardFault, ... PendSV)
  15    0x03C    systick_handler        ← we add this
  16    0x040    IRQ 0 handler
  ...
  41    0x0A4    IRQ 25 = GPIO_ODD_IRQ handler
  42    0x0A8    IRQ 26 = GPIO_EVEN_IRQ handler   ← we add this
```

Anything we don't care about points at a `default_handler` that just spins forever (so a stray interrupt is at least *visible* in GDB rather than crashing weirdly).

The full vector table and handlers are in [`main.s`](./main.s).

---

## Reading the program

`reset_handler`:

1. Initialises GPIO (clock + PC1/PC2/PC3 push-pull + PA0 input with pull-up).
2. Configures the GPIO EXTI for PA0 falling edge.
3. Enables `GPIO_EVEN_IRQn` in the NVIC.
4. Configures and starts SysTick **with `TICKINT = 1`**.
5. Drops into `wfi` (wait-for-interrupt) inside an infinite loop. The CPU sleeps until something wakes it.

`systick_handler`:

- Toggles the bit named by `active_mask` (initially red, = `1 << 1`).

`gpio_even_handler`:

- Clears the GPIO_IF flag.
- Turns *all* three LEDs off.
- Rotates `active_mask` one bit left within the {PC1, PC2, PC3} window: red → green → blue → red.

Build, flash, and look at the board:

- The active LED blinks at ~2 Hz with the CPU completely idle between ticks.
- Each press of the user button changes the colour.

> **Try it:**
> - Add a 4-state cycle: red → green → blue → all-off → red...
> - Halve the SysTick reload value to double the blink rate.
> - Read the count of GPIO_EVEN entries by incrementing a RAM word in the handler. Inspect from GDB while the device is running.

---

## Gotchas

- **Always clear the interrupt flag** in your handler. For GPIO that's writing back to `GPIO_IF` (it's a write-1-to-clear register). Forgetting this is the #1 reason "my interrupt fires forever".
- **Don't `bx lr` with the wrong `lr`.** Inside an exception handler, `lr` holds the special EXC_RETURN value — leave it alone. If you call other functions with `bl`, you must `push {lr}` first and `pop {pc}` to return, just like in Session 10.
- **The Thumb bit is still required.** Every entry in the vector table you write yourself must have `+ 1` (or use `.thumb_func` immediately before the symbol so the assembler does it for you).

---

## What you should remember

- An ISR is just a function whose address sits in the vector table at the right index.
- Configure the source (peripheral) → enable it at the source → enable the line at the **NVIC** → globally enable interrupts (Cortex-M does this by default after reset, so we don't even need a `cpsie i`).
- **Always clear the flag at the source** inside the handler.
- `wfi` lets the CPU sleep between interrupts — the hallmark of energy-efficient embedded code.

---

➡️ **Next:** [Session 12 — GDB + capstone](../12-gdb-and-capstone/) 🚀
