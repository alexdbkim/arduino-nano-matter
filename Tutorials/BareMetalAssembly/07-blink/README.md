# Session 07 — Blink the LED 🎉

> **Goal:** make the on-board red LED blink. This is the moment your bare-metal program does something **visible**.

We combine everything from sessions 4–6:

- Vector table + reset handler (Session 4),
- A few `ldr`/`str`/`orr` instructions (Session 5),
- Memory-mapped I/O — enable a clock, then poke a register (Session 6).

The result: a blinking LED that you wrote, byte by byte.

---

## What "configure a GPIO pin" means

To use **PC1** (the red LED) as a digital output we need to do three things:

1. **Enable the GPIO peripheral clock.** We did exactly this in Session 6 — set `CMU_CLKEN0[26]`.
2. **Set PC1's *mode* to "push-pull output".** Each pin has a 4-bit mode field, packed into `MODEL` (pins 0–7) or `MODEH` (pins 8–15) of its port. Mode `0x4` = push-pull.
3. **Drive the output by writing to `DOUT`.** Bit `n` of `DOUT` corresponds to pin `n`.

The on-board LEDs are **active low**: writing 0 to the pin turns the LED **on**, writing 1 turns it **off**. So toggling bit 1 of `Port C DOUT` will toggle the red LED.

> **Jargon:** **Push-pull** means the chip can both pull the pin to 3.3 V (HIGH) and pull it to GND (LOW). The opposite is **open-drain**, where the chip can only pull low. For driving an LED to ground, push-pull works fine.

---

## The addresses we need

```
GPIO_BASE      = 0x4003C000
GPIO_PC_BASE   = GPIO_BASE + 0x90       = 0x4003C090   (Port C registers start here)
   PC_MODEL    = GPIO_PC_BASE + 0x04    = 0x4003C094   (mode for pins PC0–PC7)
   PC_DOUT     = GPIO_PC_BASE + 0x10    = 0x4003C0A0   (data out for Port C)

CMU_CLKEN0     = 0x40008064             (bit 26 = GPIO clock enable)
```

Pin **PC1** is bit 1 in `DOUT` (so the bitmask `1 << 1 = 0x2`), and its mode bits in `MODEL` are bits **[7:4]** (because `pin n` occupies bits `[4n+3 : 4n]`).

To set just PC1's mode to `0x4` without disturbing the others:

```
MODEL = (MODEL & ~0xF0) | (0x4 << 4)
      = (MODEL & 0xFFFFFF0F) | 0x40
```

That's `bic` then `orr` — two instructions. We've done this exact pattern before.

---

## The blink algorithm

```text
init:
    enable GPIO clock
    set PC1 mode to push-pull (4)
loop:
    toggle bit 1 of GPIO_PC_DOUT
    delay (busy-wait)
    goto loop
```

For the delay, we just decrement a register from a big number down to zero. It's crude but it works. The chip runs at about 20 MHz out of reset (its internal `FSRCO`), so a counter of `~1_000_000` gives a delay of a few hundred milliseconds. Tweak to taste.

The full program is in [`main.s`](./main.s). Build and flash:

```sh
make
make flash
```

…and look at the board. **Red LED, blinking.** 🎉

---

## What just happened, in slow motion

1. The chip resets. The CPU reads `0x08000000` (initial SP) and `0x08000004` (your `reset_handler` address), and starts executing your code.
2. You set bit 26 of `CMU_CLKEN0` — the GPIO peripheral starts receiving a clock and wakes up.
3. You write `0x40` into the relevant nibble of `Port C MODEL` — pin PC1 is now a push-pull output, driving the red LED's cathode side.
4. In the loop, you toggle bit 1 of `Port C DOUT`. The voltage on PC1 swings between 3.3 V and 0 V.
5. When PC1 is at 0 V, current flows through the LED (because the other side is tied to 3.3 V via a resistor) and it lights up.

There is no library doing any of this. No `digitalWrite`. No HAL. Just `ldr`, `orr`, `str`.

> **Try it:**
> 1. Change `1 << 1` to `1 << 2` (PC2) — the **green** LED should blink instead.
> 2. Change to `1 << 3` (PC3) — **blue**.
> 3. Use `(1<<1) | (1<<2)` — red and green together → yellow-ish.
> 4. Make the delay much smaller. The LED will appear half-bright (your eyes integrate the fast blinking).

---

## What you should remember

- Three steps to drive a GPIO output: **clock on**, **mode = push-pull**, **write `DOUT`**.
- Each pin gets 4 bits in `MODEL`/`MODEH`. Push-pull = `0x4`.
- LEDs on the Nano Matter are **active low**: 0 = on, 1 = off.
- The pattern `bic; orr; str` is how you set a multi-bit field without touching its neighbours.

---

➡️ **Next:** [Session 08 — SysTick delay](../08-systick-delay/)
