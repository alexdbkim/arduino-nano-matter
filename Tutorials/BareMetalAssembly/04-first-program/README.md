# Session 04 — Your first program (infinite loop)

> **Goal:** write the smallest valid Thumb program (a vector table + an infinite loop), build a real `.elf` and `.bin`, and flash it onto the chip.

When this session is done, **your code is running on real silicon.** The chip won't *do* anything you can see — but it's running your bytes, not Arduino's. That's a milestone.

---

## The plan

We need three files:

1. **`main.s`** — the assembly source: a tiny vector table + a reset handler that loops forever.
2. **`linker.ld`** — a linker script that places the vector table at `0x08000000` and tells the linker where flash and RAM live.
3. **`Makefile`** — a few lines so `make`, `make flash`, and `make clean` Just Work.

All three are in this folder. Read them once, then build.

---

## `main.s` walkthrough

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
```

Three pragmas the assembler needs:

- `.syntax unified` — the modern, sane Thumb assembly syntax.
- `.cpu cortex-m33` — picks the right instruction set.
- `.thumb` — every instruction from here on is Thumb.

```asm
    .section .vectors, "a", %progbits
    .word   __stack_top
    .word   reset_handler + 1
```

The **vector table** lives in its own section called `.vectors`. Our linker script will glue this section to the very beginning of flash. We emit two 32-bit words:

- `__stack_top` (defined in the linker script as `0x20040000`).
- `reset_handler + 1` — the address of our reset handler, with the **Thumb bit** set. This is the foot-gun from Session 3 in action.

```asm
    .section .text
    .thumb_func
    .global reset_handler
reset_handler:
    b       reset_handler
```

`.thumb_func` tells the assembler "the next symbol is a Thumb function" so any reference to it gets the low bit set automatically. Then we just branch to ourselves forever — `b reset_handler`.

That's the whole program. Two words of vector table + one branch instruction = 10 bytes of code.

---

## `linker.ld` walkthrough

```ld
ENTRY(reset_handler)

MEMORY
{
    FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 1536K
    RAM   (rwx): ORIGIN = 0x20000000, LENGTH = 256K
}

__stack_top = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS
{
    .vectors : { KEEP(*(.vectors)) } > FLASH
    .text    : { *(.text*) }         > FLASH
    .rodata  : { *(.rodata*) }       > FLASH
    /DISCARD/ : { *(.ARM.*) *(.note.*) }
}
```

What's happening:

- `MEMORY` declares the two regions we learned about in Session 3.
- `__stack_top` becomes a symbol the assembler can reference (`0x20040000`).
- `SECTIONS` says **where** each input section ends up. `.vectors` goes first (so it lands at `0x08000000`), then `.text` (our code), then `.rodata` (read-only data).
- `KEEP(...)` prevents the linker from dead-stripping the vector table just because nothing in code references it by name.

---

## Build it

From this folder:

```sh
make
```

You should see:

```
arm-none-eabi-as ...
arm-none-eabi-ld ...
arm-none-eabi-objcopy -O binary main.elf main.bin
```

Inspect what you built:

```sh
arm-none-eabi-objdump -d main.elf
arm-none-eabi-objdump -h main.elf       # section headers
hexdump -C main.bin | head
```

The first 8 bytes of `main.bin` should be your initial SP and reset vector, **little-endian**:

```
00000000  00 00 04 20  09 00 00 08  ...
```

Decoded:

- `00 00 04 20` → `0x20040000` — the stack pointer. ✅
- `09 00 00 08` → `0x08000009` — your reset handler at `0x08000008`, with the Thumb bit set. ✅

Take a moment. **You just hand-built a microcontroller boot image.**

---

## Flash it

Plug in the Nano Matter via USB-C. Then:

```sh
make flash
```

Behind the scenes, this runs `JLinkExe` with a small command script that:

1. Connects to the target (`device EFR32MG24BxxxF1536`),
2. Resets and halts the core,
3. Erases the chip,
4. Loads `main.bin` into flash at `0x08000000`,
5. Resets and runs.

If you see `O.K.` near the end, your program is running. The LED won't blink — your program is just looping forever. That's expected. We'll add the blink in Session 7.

> **Gotcha:** if `JLinkExe` complains about the device name, check the J-Link tools' "supported devices" list (`JLinkExe -CommandFile -listdevices`) for the exact part number marked on your board (e.g., `EFR32MG24BxxxF1536` or similar).

> **Try it:** open another terminal and run `JLinkExe`, then at the prompt type `connect`, then `mem32 0x08000000 4` to read the first 4 words of flash. They should match the bytes you saw with `hexdump`.

---

## What you should remember

- A bare-metal program needs **(1)** a vector table at `0x08000000` and **(2)** a reset handler.
- The vector table's first word is the initial SP; the second is the reset handler address **with the Thumb bit set**.
- Build pipeline: `as` → `ld` (with linker script) → `objcopy -O binary` → flash with `JLinkExe`.
- The `KEEP(...)` directive prevents dead-stripping of the vector table.

---

➡️ **Next:** [Session 05 — Registers and the Thumb ISA](../05-registers-and-thumb/)
