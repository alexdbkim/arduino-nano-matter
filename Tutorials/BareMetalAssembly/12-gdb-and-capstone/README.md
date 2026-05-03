# Session 12 — GDB + Capstone

> **Goal:** drive your program with a real debugger — set breakpoints, single-step, inspect registers and memory — and put a final polished mini-project on the chip.

---

## Part 1 — debugging with GDB over J-Link

The Nano Matter has an on-board **J-Link OB**. We've been using `JLinkExe` to flash. Now we'll use its sibling, `JLinkGDBServer`, to talk to a real `arm-none-eabi-gdb` session over a TCP socket. From there we can:

- pause and resume the CPU,
- set breakpoints at instructions or symbols,
- single-step,
- inspect registers and memory,
- watch peripherals change while the chip runs.

### Start the GDB server

In one terminal:

```sh
JLinkGDBServer -device EFR32MG24BxxxF1536 -if SWD -speed 4000
```

You should see `Connected to target` and then it sits there waiting for a client on port `2331`.

### Connect GDB

In another terminal, in this folder:

```sh
arm-none-eabi-gdb main.elf
```

At the `(gdb)` prompt:

```
(gdb) target remote :2331
(gdb) monitor reset                # halt + reset the chip
(gdb) load                         # flash main.elf via the GDB server
(gdb) break reset_handler
(gdb) continue
```

The chip resets, runs your code up to the first instruction of `reset_handler`, and stops. Now the fun starts.

### Useful commands

| Command | What it does |
|---|---|
| `info registers`           | dump all CPU registers |
| `x/8wx 0x08000000`         | read 8 words of memory in hex |
| `x/i $pc`                  | disassemble current instruction |
| `disassemble /r $pc, +20`  | next 20 bytes of disassembly with raw bytes |
| `stepi` / `si`             | single-step **one assembly instruction** |
| `nexti` / `ni`             | step over `bl` calls (treat them as one step) |
| `continue` / `c`           | run until next breakpoint |
| `break gpio_even_handler`  | breakpoint on a symbol |
| `break *0x08000040`        | breakpoint on an exact address |
| `info breakpoints`         | list breakpoints |
| `delete 1`                 | delete breakpoint 1 |
| `print/x $r0`              | print register `r0` in hex |
| `set $r0 = 0x42`           | poke a register |
| `monitor reset`            | reset the chip (J-Link command) |

> **Try it:** set a breakpoint on `gpio_even_handler`, press the user button, and watch GDB pop you into the handler. Then `info registers` to see the CPU state right at the moment of the interrupt.

A `.gdbinit` file in this folder pre-loads `main.elf`, connects to the server, and resets — so you can just run `arm-none-eabi-gdb` and be ready to go.

---

## Part 2 — the capstone project

In [`main.s`](./main.s), this session ships a polished version of the interrupt-driven blink:

- **SysTick interrupt** blinks the active LED at 2 Hz.
- **GPIO_EVEN interrupt** rotates through the RGB cycle (red → green → blue → red…) on each button press.
- **Bonus:** an additional state — pressing past blue lands on **all-off**, then back to red. A small pattern-counter lives in RAM at `0x20000004` so you can watch it from GDB.

The goal isn't new hardware features — it's that you now have a fully working, **fully interrupt-driven**, fully assembly bare-metal program that reacts to a physical button in real time.

Build, flash, debug:

```sh
make
make flash
arm-none-eabi-gdb            # picks up .gdbinit and connects automatically
(gdb) continue
```

Press the button, watch the LED pattern change. While running, hit `Ctrl-C` in GDB to halt — read `0x20000000` (active mask) and `0x20000004` (press counter) to see the live state.

---

## A debugging exercise

Here are three deliberate experiments — try each and see what happens, then explain *why*:

1. **Comment out** the `str r1, [r0]` that clears `GPIO_IF` inside `gpio_even_handler`. What happens when you press the button?
2. **Set the wrong port** in `EXTIPSELL` (e.g., PORTB). What happens when you press the button?
3. **Forget the Thumb bit** in the SysTick vector entry: change `systick_handler + 1` to just `systick_handler`. What happens after a SysTick fires?

Each of these reproduces a real bug a beginner would write. Catching them with GDB is the muscle memory you want.

---

## What you should remember

- `JLinkGDBServer` ↔ `arm-none-eabi-gdb` over port **2331** is the universal Cortex-M debug stack.
- `stepi`, `nexti`, `info registers`, and `x/...` are the four commands you'll use 90% of the time.
- A `.gdbinit` saves typing — keep one per project.
- You can now write, flash, and debug a fully interrupt-driven program in **pure ARM Thumb assembly**, on real silicon.

🎉 **You finished the series.** From here, suggested next stops:

- Add a UART so the chip can `printf` over USB.
- Configure the high-frequency clock and run at the full 78 MHz.
- Mix in C: write a `.c` file, compile it with `arm-none-eabi-gcc`, and call its functions from your assembly (`bl my_c_function`). AAPCS makes this Just Work.
- Read the ARMv8-M ARM section on TrustZone — and try splitting your program into a Secure boot stub and a Non-Secure application.

---

*Thank you for sticking with it. Now go break something on purpose and fix it.*
