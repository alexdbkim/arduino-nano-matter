# Bare-Metal Assembly on the Arduino Nano Matter — Intro

Welcome! 👋 This is a self-paced tutorial series where we learn to talk to a microcontroller in its native language — **assembly** — with absolutely nothing in between. No operating system. No Arduino libraries. No C. Just you, a tiny chip, and the bytes you write.

By the end of session 12 you will:

- understand what really happens when a microcontroller "boots",
- write, assemble, link, and flash your own programs from the command line,
- blink an LED, read a button, handle interrupts, and debug live with GDB —
- all in **ARM Thumb assembly**, on the Arduino Nano Matter.

---

## Who this is for

You. Specifically:

- You've maybe blinked an LED with `digitalWrite()` once, but you don't have to have.
- You don't need to know C, assembly, or anything about ARM.
- You just need curiosity and a willingness to read register tables.

If you can copy-paste a command into a terminal and you've heard the word "binary" before, you're qualified.

> **ELI5:** "Bare metal" means we're writing code that runs **directly on the chip**, with no helper software underneath. Think of it like cooking from raw ingredients instead of microwaving a frozen dinner.

---

## What you'll need

### Hardware

- 1× **Arduino Nano Matter** (Silicon Labs MGM240SD22VNA, ARM Cortex-M33).
- 1× USB-C cable (data, not just power).
- A computer running **macOS**.

The Nano Matter has an on-board **CMSIS-DAP debug probe** (firmware running on the small ATSAMD11 USB bridge), so you can flash and debug straight over USB — no extra hardware required.

### Software (we'll install this together in Session 2)

- **GNU Arm Embedded toolchain** — `arm-none-eabi-gcc`, `as`, `ld`, `objcopy`, `gdb` (via Homebrew).
- **OpenOCD** — `brew install open-ocd`. Acts as both flasher and GDB server, talks to the on-board CMSIS-DAP probe over USB.
- **VS Code** + **Cortex-Debug** + **C/C++** + **ARM** extensions — for breakpoints, register/memory inspection, and graphical single-stepping.

> **No Arduino IDE. No Simplicity Studio.** Everything is command-line. This is on purpose — when you build it yourself, you understand it.

---

## The chip we're targeting

| | |
|---|---|
| MCU | Silicon Labs MGM240SD22VNA |
| Core | ARM Cortex-M33, ARMv8-M Mainline |
| Instruction set | **Thumb-2 only** (no classic 32-bit ARM mode) |
| Clock | up to 78 MHz |
| Flash | 1536 kB |
| RAM | 256 kB |
| Demo peripherals | on-board RGB LED, user pushbutton |

> **ELI5:** "Thumb-2" is just the name of the dialect of assembly the Cortex-M33 speaks. Every instruction we write will be Thumb. You don't have to memorise that — just don't be surprised when you see the word.

---

## How the series is organised

Each session lives in its own folder next to this file:

```
Tutorials/BareMetalAssembly/
├── Intro.md                    ← you are here
├── 01-what-is-bare-metal/
├── 02-toolchain-setup/
├── 03-memory-map-and-vector-table/
├── 04-first-program/
├── 05-registers-and-thumb/
├── 06-memory-mapped-io/
├── 07-blink/
├── 08-systick-delay/
├── 09-button-input/
├── 10-subroutines-and-aapcs/
├── 11-interrupts/
└── 12-gdb-and-capstone/
```

Each session folder will contain:

- a `README.md` that walks you through the lesson (read this first),
- the `.s` (assembly) and `.ld` (linker script) source files,
- a tiny `Makefile` so `make` builds, `make flash` flashes, and `make clean` tidies up.

You're meant to **type the code yourself**, not copy-paste. That's where the learning lives.

---

## The 12-session syllabus

| # | Title | What you'll do | What you'll learn |
|---|---|---|---|
| 1 | What is bare metal? | Tour the Nano Matter, draw a picture of CPU + memory + peripherals | Mental model: MCU vs. PC, what "no OS" really means, why assembly exists |
| 2 | Toolchain setup (macOS) | Install `arm-none-eabi-*` and OpenOCD; assemble a do-nothing program; wire up VS Code for breakpoint debugging | What an assembler, linker, and object file are; how OpenOCD bridges your Mac and the on-board CMSIS-DAP probe |
| 3 | Memory map & the vector table | Read the MGM240S memory map; lay out flash and RAM regions on paper | Why the **first 8 bytes** of flash are the initial stack pointer and the reset handler |
| 4 | Your first program | Write a 4-instruction Thumb program that loops forever; build `.elf` → `.bin`; flash it | The full pipeline `assemble → link → objcopy → flash`; minimal linker script |
| 5 | Registers & the Thumb ISA | Hand-trace a tiny program on paper, then verify on the chip | `r0`–`r15`, `SP`, `LR`, `PC`, `xPSR`; `mov`, `add`, `sub`, `ldr`, `str` |
| 6 | Memory-mapped I/O | Look up the GPIO base address in the EFR32MG24 reference manual; poke a register from asm | What MMIO is; how peripherals look like memory |
| 7 | Blink the LED 🎉 | Configure a GPIO pin as output and toggle it in a loop | Your first **observable** bare-metal result |
| 8 | Delays & SysTick | Replace busy-wait with a real timer; make a 1-second blink | The SysTick peripheral; why timers beat counting NOPs |
| 9 | Reading a button | Configure an input pin with a pull-up; LED mirrors the user button | Input direction, pull-ups, polling |
| 10 | Subroutines & AAPCS | Refactor blink into `delay_ms` and `led_toggle` functions | `bl` / `bx lr`, prologue/epilogue, argument passing in `r0`–`r3`, callee-saved registers |
| 11 | Interrupts | Add a SysTick handler and a GPIO interrupt; remove all polling | The NVIC, populating the vector table, what an ISR is |
| 12 | GDB + capstone project | Connect `arm-none-eabi-gdb` to OpenOCD; break, step, inspect; build the final mini-project | Live debugging; an interrupt-driven button-controlled RGB pattern, all in assembly |

---

## ELI5 conventions used in this series

You'll see these little call-outs throughout the sessions:

> **Jargon:** A short box that defines a new word the **first** time it appears. Skip it if you already know.

> **Try it:** A small experiment — change a number, see what happens. Two minutes, big payoff.

> **Gotcha:** A foot-gun warning. The author has stepped on these so you don't have to.

> **Why?:** A short detour explaining *why* a thing is the way it is. Optional.

---

## What this series is **not**

- ❌ Not a C tutorial. We won't write any C until you ask for it.
- ❌ Not an RTOS or FreeRTOS course.
- ❌ Not Arduino-IDE-based — the IDE is hiding all the parts we want to see.
- ❌ Not an exhaustive ARM reference. We learn just enough Thumb-2 to build cool things.
- ❌ Not about Matter, Thread, or Bluetooth (those live way above bare metal).

---

## References & further reading

You don't need to read any of these to follow along — but they're the source of truth when you want to go deeper.

- [**Arm Architecture Reference Manual, ARMv8-M**](https://developer.arm.com/documentation/ddi0553/latest/) — the canonical spec for the instruction set.
- [**Arm Cortex-M33 Processor Technical Reference Manual (TRM)**](https://developer.arm.com/documentation/100230/latest/) — the core's behaviour, NVIC, SysTick, MPU.
- [**Silicon Labs EFR32MG24 Reference Manual**](https://www.silabs.com/documents/public/reference-manuals/efr32xg24-rm.pdf) — peripheral registers, GPIO, clocks (the MGM240S module is built around an EFR32MG24).
- [**Silicon Labs MGM240S datasheet**](https://www.silabs.com/documents/public/data-sheets/mgm240s-datasheet.pdf) — pinout and electrical characteristics.
- [**Arduino Nano Matter documentation**](https://docs.arduino.cc/hardware/nano-matter/) — board pin mapping and schematic.
- [**Arduino Nano Matter user manual / cheat sheet**](https://docs.arduino.cc/tutorials/nano-matter/user-manual/) — pin-by-pin reference for the board.
- [**Procedure Call Standard for the Arm Architecture (AAPCS)**](https://github.com/ARM-software/abi-aa/blob/main/aapcs32/aapcs32.rst) — the calling-convention rules we use in Session 10.
- [**GNU `as` (Arm) manual**](https://sourceware.org/binutils/docs/as/ARM-Dependent.html) — every directive and syntax quirk of the assembler.
- [**Joseph Yiu, *The Definitive Guide to Arm Cortex-M23 and Cortex-M33 Processors***](https://www.elsevier.com/books/the-definitive-guide-to-arm-cortex-m23-and-cortex-m33-processors/yiu/978-0-12-820735-2) — friendly book-length companion if you want one.

---

Ready? Open up [`01-what-is-bare-metal/`](./01-what-is-bare-metal/) and let's go. 🚀
