# Session 06 — Memory-mapped I/O

> **Goal:** understand that **peripherals look just like memory**, then write a tiny program that turns on the GPIO clock by writing to a single bit of a single register.

This session bridges "doing arithmetic in RAM" (Session 5) and "blinking an LED" (Session 7). It introduces **the** technique you'll use for every peripheral: read or write a 32-bit word at a fixed address, and the hardware does something.

---

## Memory-mapped I/O (MMIO)

On the EFR32MG24, peripherals don't have special instructions. Instead, every peripheral register is wired up to a fixed address in the chip's address space. Want to control GPIO? Write to addresses near `0x4003C000`. Want to enable a clock? Write to `0x40008064`. That's it.

```
                     write 0x04000000 to 0x40008064
your code  ─────────────────────────────────────────►  CMU peripheral
                                                       (turns on the GPIO clock)
```

Same `str` instruction we used in Session 5. **The address is what makes it special.**

> **Jargon:** **MMIO** = **memory-mapped I/O**. A peripheral register that you read/write with normal load/store instructions. As opposed to "port-mapped I/O" you'd find on x86, which uses dedicated `in`/`out` instructions. ARM doesn't have those — every peripheral is MMIO.

---

## Where do these magic addresses come from?

The **EFR32xG24 Reference Manual** (link in the top-level Intro.md). For each peripheral, it gives:

1. The **base address**.
2. A table of **register offsets** from that base.
3. The **bit fields** within each register and what they do.

You combine those three to get any peripheral register's full address. For our chip:

| Peripheral | Base address (secure alias) |
|---|---|
| CMU (clock manager) | `0x40008000` |
| GPIO | `0x4003C000` |

For this session we only care about one register inside CMU: **`CLKEN0`** (Clock Enable 0). Its offset in the CMU register block is `0x64`, so its full address is:

```
CMU_BASE + CMU_CLKEN0_OFFSET = 0x40008000 + 0x64 = 0x40008064
```

Inside `CLKEN0`, the bit at position **26** is the GPIO clock enable. Set it to 1 and the GPIO peripheral gets a clock; until then, GPIO writes won't do anything.

> **Gotcha:** Many SiLabs / EFR32 peripherals have their clock **disabled by default after reset** to save power. If your GPIO/UART/etc. seems to ignore writes, this is the #1 reason. We'll always enable the clock first.

---

## What we'll do

The program in [`main.s`](./main.s):

1. Loads the address `0x40008064` into a register.
2. Reads its current value.
3. Sets bit 26.
4. Writes it back.
5. Loops forever.

After this runs, `CMU_CLKEN0` bit 26 is `1` and the GPIO peripheral is alive. We can't *see* this from outside the chip — but in Session 7 we'll trust that it worked, then write to GPIO and see the LED light up.

You can verify the write with GDB:

```sh
make flash
JLinkGDBServer -device EFR32MG24BxxxF1536 -if SWD &
arm-none-eabi-gdb main.elf
(gdb) target remote :2331
(gdb) monitor reset
(gdb) continue
^C
(gdb) x/wx 0x40008064
0x40008064:    0x04000000      ← bit 26 is set. ✅
```

`0x04000000` in binary is `0000 0100 0000 0000 0000 0000 0000 0000` — exactly bit 26.

---

## The read-modify-write pattern

Most peripheral writes follow this dance:

```asm
    ldr   r1, [r0]        @ read current value
    orr   r1, r1, r2      @ set bits we want (bitwise OR)
    str   r1, [r0]        @ write it back
```

To **clear** bits instead:

```asm
    ldr   r1, [r0]
    bic   r1, r1, r2      @ bit-clear: r1 &= ~r2
    str   r1, [r0]
```

To **toggle**:

```asm
    ldr   r1, [r0]
    eor   r1, r1, r2      @ XOR
    str   r1, [r0]
```

Memorise these three patterns. They cover almost everything.

> **Why?:** Why not just `mov r1, #constant; str r1, [r0]`? Because peripheral registers usually contain *several* bit fields, and you only want to change the one you care about — not stomp on the others.

---

## Try it

After running, attach GDB and:

1. Read `0x40008064` — confirm bit 26 is set.
2. Read `0x4003C000` (the start of GPIO) — see what's there.
3. Try poking different bits of `CLKEN0` and seeing what they enable (look up bit 0, 1, etc. in the reference manual).

---

## What you should remember

- Peripherals are just memory at fixed addresses (MMIO).
- The reference manual is the source of truth: **base + offset + bit field**.
- On the EFR32MG24, **most peripherals' clocks are off after reset**. Set the right bit in `CMU_CLKEN0` (`0x40008064`) before using a peripheral.
- **Read-modify-write** is the universal pattern: `ldr` → `orr`/`bic`/`eor` → `str`.

---

➡️ **Next:** [Session 07 — Blink the LED](../07-blink/) 🎉
