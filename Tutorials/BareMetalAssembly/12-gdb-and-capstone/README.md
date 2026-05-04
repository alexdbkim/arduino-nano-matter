# Session 12 — GDB + Capstone

> **Goal:** drive your program with a real debugger — set breakpoints, single-step, inspect registers and memory — and put a final polished mini-project on the chip.

---

## Part 1 — debugging with GDB over OpenOCD

The Nano Matter has an on-board **CMSIS-DAP probe** (firmware running on the small ATSAMD11 USB bridge). We've been using **OpenOCD** to flash. The same `openocd` process is also a full GDB server — leave it running and connect `arm-none-eabi-gdb` to it. From there we can:

- pause and resume the CPU,
- set breakpoints at instructions or symbols,
- single-step,
- inspect registers and memory,
- watch peripherals change while the chip runs.

### Start the GDB server

In one terminal, from this folder:

```sh
make gdbserver
# which is the same as:
# openocd -f interface/cmsis-dap.cfg -f target/efm32.cfg
```

OpenOCD prints something like `Listening on port 3333 for gdb connections` and sits there waiting for a client.

### Connect GDB

In another terminal, in this folder:

```sh
arm-none-eabi-gdb main.elf
```

At the `(gdb)` prompt:

```
(gdb) target extended-remote :3333
(gdb) monitor reset halt           # halt + reset the chip
(gdb) load                         # flash main.elf via the GDB server
(gdb) break reset_handler
(gdb) continue
```

The chip resets, runs your code up to the first instruction of `reset_handler`, and stops. Now the fun starts.

> **Why `extended-remote`?** With plain `target remote`, GDB will detach if the target dies. `extended-remote` keeps the session alive and lets you re-`run` / re-`load` without reconnecting. OpenOCD supports both.

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
| `monitor reset halt`       | reset the chip and halt at vector reset (OpenOCD command) |
| `monitor reset run`        | reset the chip and let it run free |
| `monitor halt` / `monitor resume` | manual halt and resume |
| `monitor flash write_image erase main.bin 0x08000000` | re-flash without `load` |

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

- **OpenOCD** ↔ `arm-none-eabi-gdb` over port **3333** is the universal Cortex-M debug stack on the Nano Matter (the on-board ATSAMD11 speaks CMSIS-DAP, OpenOCD speaks both ends).
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
