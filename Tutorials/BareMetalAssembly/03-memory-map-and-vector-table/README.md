# Session 03 — Memory map & the vector table

> **Goal:** know exactly where flash and RAM live on our chip, and what the very first bytes of flash mean.

This session is all reading and one diagram. There's no code yet. **But** what you learn here is the foundation for every program we'll write.

---

## The chip's memory map

Every microcontroller has a **memory map** — a giant 32-bit address space (4 GB) where each region is reserved for something. On the EFR32MG24 the parts we care about are:

```
  0xFFFFFFFF ┌────────────────────────────┐
             │     System / private       │  (NVIC, SysTick, debug regs live here)
  0xE0000000 ├────────────────────────────┤
             │      (lots of nothing)     │
  0x50000000 ├────────────────────────────┤
             │  Peripherals (NS alias)    │  GPIO_NS = 0x5003C000
  0x40000000 ├────────────────────────────┤
             │  Peripherals (S alias)     │  GPIO_S  = 0x4003C000
             │                            │  CMU_S   = 0x40008000
             │                            │
  0x20040000 ├────────────────────────────┤
             │            RAM             │  256 kB
  0x20000000 ├────────────────────────────┤
             │      (lots of nothing)     │
  0x08180000 ├────────────────────────────┤
             │           Flash            │  1536 kB ← your program lives here
  0x08000000 ├────────────────────────────┤
             │      (lots of nothing)     │
  0x00000000 └────────────────────────────┘
```

Two addresses to memorise:

| Symbol | Address | What |
|---|---|---|
| `FLASH_BASE` | `0x08000000` | Start of program flash. Your `.text` section goes here. |
| `SRAM_BASE`  | `0x20000000` | Start of RAM. Initial top-of-stack = `0x20000000 + 256 kB` = `0x20040000`. |

> **Jargon:** "S" / "NS" stand for **secure** / **non-secure**. The Cortex-M33 supports ARM TrustZone, which splits the address space in two. After reset, the CPU runs in **secure** state, so we'll always use the `S` aliases (the `0x4xxxxxxx` ones). Treat the NS aliases as "the same registers, viewed from non-secure code".

---

## The vector table

The first thing the CPU does after reset is look at flash and read **two 32-bit words**. That tiny 8-byte structure — and a bunch of similar entries that follow — is called the **vector table**.

```
flash address    contents               meaning
0x08000000       0x20040000             initial Stack Pointer (top of RAM)
0x08000004       0x08000009             Reset handler address (Thumb bit set!)
0x08000008       <NMI handler>          ...
0x0800000C       <HardFault handler>
0x08000010       <MemManage handler>
0x08000014       <BusFault handler>
0x08000018       <UsageFault handler>
...              ...                    (16 ARM-defined entries, then peripheral IRQs)
```

When you press reset, the CPU literally:

1. Reads 4 bytes at `0x08000000` and loads them into `SP` (the stack pointer).
2. Reads 4 bytes at `0x08000004`, clears the low bit, and jumps to that address as the first instruction.

That's the whole boot sequence. There is no BIOS, no bootloader (in this tutorial), nothing else. The hardware does these two reads and your code takes over.

> **Gotcha — the Thumb bit:** On Cortex-M, every function pointer must have its **least significant bit set to 1** to indicate "this is Thumb code". The CPU clears that bit before fetching the actual instruction, but if you forget to set it, the CPU will think you're trying to run classic ARM code and immediately HardFault. The assembler does this for us automatically when we say `.thumb_func` — but it's good to know why.

---

## What goes after the first 8 bytes?

The full ARMv8-M vector table starts with 16 system entries, then lists every interrupt the chip has, in order. Skipping the system part for now, peripheral IRQ #0 starts at offset `64 + 0` = entry index 16:

```
entry  offset  name
   0   0x00    initial SP
   1   0x04    Reset
   2   0x08    NMI
   3   0x0C    HardFault
   ...
  15   0x3C    SysTick     ← we use this in Session 8
  16   0x40    IRQ 0  (first peripheral)
  17   0x44    IRQ 1
   ...
  41   0xA4    IRQ 25 = GPIO_ODD     ← Session 11
  42   0xA8    IRQ 26 = GPIO_EVEN    ← Session 11 (PA0 button)
   ...
```

We won't fill all of these in. For our tiny programs, we only need:

- entry 0 (initial SP),
- entry 1 (Reset handler — points to our code),
- and (in Session 11) the SysTick + GPIO entries.

Everything else can stay zero, which means "if this interrupt ever fires, jump to address 0 and crash." That's fine for a tutorial — we just won't enable interrupts we haven't written handlers for.

---

## Why does the stack point to the *top* of RAM?

The Cortex-M stack grows **downwards** — every `push` decreases SP, every `pop` increases it. So we set the initial SP to the highest RAM address (`0x20040000`) and let it grow down toward our variables.

In our linker script (next session) you'll see:

```ld
__stack_top = 0x20040000;
```

…and the very first word of the vector table is initialised to `__stack_top`.

---

## Try it (still on paper)

Sketch the layout of the first 32 bytes of flash for our future program:

```
0x08000000:  ?? ?? ?? ??     <- initial SP   (we'll fill in 0x20040000)
0x08000004:  ?? ?? ?? ??     <- reset handler addr
0x08000008:  00 00 00 00     <- NMI       (unused)
0x0800000C:  00 00 00 00     <- HardFault (unused)
... etc.
```

Don't worry about endianness for now — the toolchain handles it. (Spoiler: it's little-endian, so the bytes appear "reversed" in a hex dump.)

---

## What you should remember

- Flash starts at **`0x08000000`**, RAM at **`0x20000000`**, RAM top is **`0x20040000`**.
- The first 8 bytes of flash are **initial SP** and **reset handler address** — that's the whole boot.
- Function pointers in the vector table must have the **Thumb bit (bit 0) set** to 1.
- Peripherals live in the **`0x4xxxxxxx`** range; we'll start poking GPIO at `0x4003C000` in Session 6.

---

➡️ **Next:** [Session 04 — Your first program](../04-first-program/)
