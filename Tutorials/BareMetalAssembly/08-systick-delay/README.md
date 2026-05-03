# Session 08 — Real delays with SysTick

> **Goal:** replace the embarrassing `subs/bne` busy-loop from Session 7 with a proper hardware timer. By the end you'll have a clean 1-Hz blink.

The problem with our blink so far is that the delay depends on how many cycles the CPU takes per loop iteration — which changes if you turn on optimisations, change clock speed, or add more code. We need a real clock.

---

## Meet SysTick

Every Cortex-M chip ships with a built-in **24-bit countdown timer** called **SysTick**. It's part of the core itself (not a vendor peripheral), so its registers and behaviour are the same on every M0/M3/M4/M7/M33.

It has just **four registers**, all in the system control space at `0xE000E010`:

| Address | Name | What it does |
|---|---|---|
| `0xE000E010` | `SYST_CSR` (Control & Status) | enable, IRQ enable, clock source, count-flag |
| `0xE000E014` | `SYST_RVR` (Reload Value) | what value to reload when it hits 0 |
| `0xE000E018` | `SYST_CVR` (Current Value) | the live counter; write any value to clear |
| `0xE000E01C` | `SYST_CALIB` | implementation hints (we ignore it) |

Bits we care about in `SYST_CSR`:

| Bit | Name | Meaning |
|---|---|---|
| 0 | `ENABLE` | 1 = counter is running |
| 1 | `TICKINT` | 1 = generate an interrupt when it hits 0 (we leave it 0 for now) |
| 2 | `CLKSOURCE` | 0 = external ref clock; **1 = processor clock** (we use this) |
| 16 | `COUNTFLAG` | 1 = the counter wrapped since you last read this register |

How it works:

1. You write a reload value `N` into `RVR`.
2. You write any value to `CVR` to clear the live counter.
3. You write `CSR = (1<<2) | (1<<0)` — clock source = CPU, enable = 1.
4. The counter starts at `N` and decrements once per CPU cycle.
5. When it hits 0, it auto-reloads back to `N`. Bit 16 of `CSR` becomes 1.
6. The next read of `CSR` gives you that bit and clears it.

**Polling for one tick** = "wait until reading `CSR` shows bit 16 = 1".

> **Gotcha:** `RVR` is **only 24 bits**. The maximum value is `0xFFFFFF` = 16 777 215. Our chip runs at ~20 MHz out of reset (the internal `FSRCO`). One full second would need ~20 000 000 ticks — more than 24 bits can hold. So we'll count 1 ms at a time (20 000 ticks per ms) and loop.

---

## Our `delay_ms` routine

Pseudocode:

```c
void delay_ms(uint32_t ms) {
    SYST_RVR = 20000 - 1;          // 1 ms at ~20 MHz
    SYST_CVR = 0;                  // clear current
    SYST_CSR = (1<<2) | (1<<0);    // clock=CPU, enable
    while (ms--) {
        while ((SYST_CSR & (1<<16)) == 0) { /* spin */ }
    }
    SYST_CSR = 0;                  // disable when done
}
```

In assembly that's about 15 instructions. See [`main.s`](./main.s).

The blink loop is now satisfyingly clean:

```asm
blink_loop:
    eor   r6, r6, r5         @ toggle LED bit
    str   r6, [r4]
    mov   r0, #500           @ delay_ms(500)
    bl    delay_ms
    b     blink_loop
```

That's a **half-second on, half-second off** blink — a proper 1-Hz square wave on PC1.

> **Why ~20 MHz?** After a cold reset, before any code touches the clock manager, the EFR32MG24 runs from its built-in `FSRCO` (Fast Startup RC Oscillator) at 20 MHz. We don't change clocks in this series — that's a whole topic on its own — so 20 MHz is what we work with.

---

## Try it

1. Change `mov r0, #500` to `mov r0, #100` — much faster blink.
2. Change to `mov r0, #2000` — slow heartbeat.
3. Make red blink at 1 Hz and green blink at 2 Hz from the same loop. (Hint: alternate which DOUT bits you toggle.)
4. Read `SYST_CVR` from GDB while halted to see the live counter.

---

## What you should remember

- SysTick is a 24-bit countdown timer that lives at `0xE000E010` on every Cortex-M.
- The four registers: `CSR` (control/status), `RVR` (reload), `CVR` (current), `CALIB`.
- Polling: write `(1<<2)|(1<<0)` to `CSR` then watch bit 16 of `CSR` for a tick.
- 24 bits is small — for long delays, count milliseconds and loop.

---

➡️ **Next:** [Session 09 — Reading a button](../09-button-input/)
