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

Behind the scenes, this runs the **Silicon Labs–forked OpenOCD** (the one the Arduino core installs) with the CMSIS-DAP interface and the `efm32s2_g23.cfg` target script. It connects through the on-board ATSAMD11 USB bridge, halts the core, erases the relevant flash sectors, programs `main.elf` into flash starting at `0x08000000`, verifies the write, and resets the chip so your program starts running.

The single OpenOCD command underneath is:

```sh
SILABS_OOCD=~/Library/Arduino15/packages/SiliconLabs/tools/openocd/0.12.0-arduino1-static
"$SILABS_OOCD/bin/openocd" -s "$SILABS_OOCD/share/openocd/scripts" \
    -f interface/cmsis-dap.cfg -f target/efm32s2_g23.cfg \
    -c "init; reset_config srst_nogate; reset halt; program main.hex verify; reset; exit"
```

If you see `** Programming Finished **` and `** Verified OK **` near the end, your program is running. The LED won't blink — your program is just looping forever. That's expected. We'll add the blink in Session 7.

> **Gotcha:** if OpenOCD complains *"Can't find target/efm32s2_g23.cfg"*, you're running vanilla Homebrew `openocd` instead of the Silicon Labs–forked one. Install the Silicon Labs Arduino core (Session 02) and use the binary at `~/Library/Arduino15/.../0.12.0-arduino1-static/bin/openocd`.

> **Gotcha:** if OpenOCD says *"unable to find a matching CMSIS-DAP device"*, the macOS USB stack doesn't see the on-board probe. Try a different USB-C cable (must be data, not power-only), plug directly into the Mac (no hub), and confirm enumeration with `ioreg -p IOUSB -l | grep -E '"USB Product Name"'`.

> **Try it:** open another terminal and run `make gdbserver`. Then in a third terminal, `arm-none-eabi-gdb main.elf`, and at the `(gdb)` prompt: `target extended-remote :3333`, `monitor reset halt`, `x/2wx 0x08000000`. The first 4 words of flash should match the bytes you saw with `hexdump`.

---

## Break into the board from VS Code (step-by-step)

Flashing from the command line is great. But the real superpower is **stopping the chip on a specific instruction and poking at it live** — registers, memory, the works. Here is exactly how to do that in VS Code, the first time.

### Prerequisites (one-time)

You should already have these from Session 02:

- The **Arduino IDE + Silicon Labs core** installed (gives us the working OpenOCD at `~/Library/Arduino15/.../0.12.0-arduino1-static/`).
- VS Code extensions: **C/C++** (Microsoft), **Cortex-Debug** (marus25), and **ARM** (dan-c-underwood).
- The board plugged in via a **data** USB-C cable.

You don't need to configure anything — `04-first-program/.vscode/{launch,settings,tasks}.json` are already wired up for you.

### Step 1 — open this folder as the workspace

From a terminal:

```sh
cd 04-first-program
code .
```

The folder must be the workspace root. If you open the parent `BareMetalAssembly/` folder, VS Code won't find `.vscode/launch.json`.

### Step 2 — verify the probe is alive

Open the integrated terminal (**⌃`**) and run:

```sh
ls /dev/cu.usbmodem*
```

You should see something like `/dev/cu.usbmodem9FA69C6B3`. If it's missing, the board isn't enumerating — re-seat the cable before going further. Don't waste 30 minutes debugging "Cortex-Debug failed to launch" when the actual problem is USB.

### Step 3 — set a breakpoint

Open `main.s`. Click in the **gutter** (the empty space just left of the line numbers) next to **line 24**, the `b reset_handler` instruction:

```asm
21    nop
22    nop
23    nop
24    b   reset_handler   @ infinite loop
```

A **solid red dot** appears. That's a bound breakpoint. Cortex-Debug supports up to **8 hardware breakpoints** simultaneously on this chip — more than you'll ever need.

> **The #1 reason breakpoints "don't work":** you clicked a line that has **no instruction** — the `reset_handler:` label (line 20), the vector-table data (lines 10–11), a comment, or a blank. GDB has no address to bind to, so VS Code shows a **hollow grey circle** instead of a solid red dot, and the chip flies right past it. **Only click on lines with an actual instruction** (`nop`, `b`, `mov`, etc.). You can verify which lines map to instructions by running `arm-none-eabi-objdump --dwarf=decodedline main.elf` — only those line numbers are breakpointable.

> **Also:** `runToEntryPoint: reset_handler` in `launch.json` already auto-halts you at the first instruction of `reset_handler` on launch. So even with **zero** manual breakpoints, F5 will stop on line 21. The breakpoint on line 24 is what catches you *after* you press Continue.

### Step 4 — press F5

Hit **F5** (or **Run → Start Debugging** from the menu). You'll see, in order:

1. The **build task** runs — `make` compiles `main.s` → `main.o` → `main.elf`. This is configured by `"preLaunchTask": "build"` in `launch.json`, so you never debug a stale binary.
2. **OpenOCD starts** (in a hidden "gdb-server" terminal at the bottom). It connects to the CMSIS-DAP probe, halts the M33, and listens on port 3333. You should see the same banner you saw with `make flash` — `Cortex-M33 r0p4 processor detected`, `flash size = 1536 KiB`, `** Verified OK **`.
3. **`arm-none-eabi-gdb` launches**, attaches to OpenOCD on `:3333`, flashes a fresh `main.elf`, resets the chip, and **halts at `reset_handler`** (because `"runToEntryPoint": "reset_handler"` is set in `launch.json`).

When the dust settles, the editor jumps to `main.s` with a yellow arrow on the first instruction of `reset_handler`. **The chip is now frozen, waiting for you.**

### Step 5 — explore the debug UI

While halted, look at the left sidebar — these panels are now live:

- **VARIABLES → CPU Core Register** — every Cortex-M33 register: `r0`–`r15`, `xPSR`, `MSP`, `PSP`, `CONTROL`, `PRIMASK`, `FAULTMASK`, `BASEPRI`. Updates after every halt.
- **WATCH** — pin live expressions. Try adding `$pc`, `$sp`, `$lr`, `*0x08000000` (the first word of flash — should be the stack-top, `0x20040000`).
- **CALL STACK** — currently just `reset_handler`. Will fill out once we use `bl` in Session 10.
- **BREAKPOINTS** — your `b .` breakpoint, plus a checkbox to disable it without removing.

The **debug toolbar** at the top (or **F-keys**) drives execution:

| Key | Action | When you'd use it |
|---|---|---|
| **F5** | Continue | Run until next breakpoint (or forever, in our case). |
| **F10** | Step Over | Execute one source line. |
| **F11** | Step In | Step into a `bl` call (irrelevant here — no calls yet). |
| **⇧F11** | Step Out | Run to the return of the current function. |
| **⌘⇧F5** | Restart | Reset the chip and re-halt at `reset_handler`. |
| **⇧F5** | Stop | End the debug session. The chip keeps running whatever was last flashed. |

### Step 6 — single-step the reset handler

You're halted on **line 21** (`nop`). Press **F10** three times and watch the yellow arrow walk down through:

```asm
21    nop          @ ← halted here on entry
22    nop
23    nop
24    b   reset_handler   @ ← branches back to line 21 forever
```

Open **VARIABLES → CPU Core Register** and watch **`pc`** tick up by **2 bytes** per step — `0x08000008 → 0x0800000a → 0x0800000c → 0x0800000e` — because Thumb `nop` is a 16-bit instruction. The fourth step (the `b`) takes you back to `0x08000008`. You're now spinning the loop one orbit at a time.

Watch **`xPSR`** while you step — its bit 24 (`T`, the Thumb bit) should stay set. If it ever clears, the next instruction would HardFault.

### Step 7 — read flash live

Open the **Memory** view: **⌘⇧P → "Cortex-Debug: View Memory"**, then enter address `0x08000000` and length `32`. You should see the bytes you decoded by hand earlier — `00 00 04 20 09 00 00 08 ...` — but read directly from the chip over SWD this time. You can also write memory from this view, though we won't here.

### Step 8 — view the disassembly

**⌘⇧P → "Open Disassembly View"**. VS Code drops you into a pane showing the actual machine code that's running, interleaved with your `.s` source. The yellow arrow tracks `pc`. This is the view you'll fall in love with as the programs get bigger — it's the one place where ARM Thumb encoding becomes concrete.

### Step 9 — stop the session

Press **⇧F5** (or click the red square on the toolbar). VS Code stops `gdb` and `openocd`. The chip keeps running your code — your infinite loop just continues spinning until the next reset or `make flash`.

> **Gotcha — "Failed to launch OpenOCD":** check the **DEBUG CONSOLE** panel for the actual error. 99% of the time it's a wrong path. Open `.vscode/settings.json` and make sure `cortex-debug.openocdPath` points at the Silicon Labs–forked binary at `~/Library/Arduino15/packages/SiliconLabs/tools/openocd/0.12.0-arduino1-static/bin/openocd`.

> **Gotcha — yellow arrow stuck on a line that isn't `reset_handler`:** you flashed once, didn't reset, and re-attached. Use **⌘⇧F5** (Restart) to force a reset-and-halt.

> **Gotcha — breakpoint shows as a hollow grey circle:** the line you clicked has no instruction associated with it (it's a label, comment, blank, or the `.word` data in the vector table). GDB can't bind it. Move the breakpoint to a line that actually contains an instruction — use `arm-none-eabi-objdump --dwarf=decodedline main.elf` to list the breakpointable lines.

---

## What you should remember

- A bare-metal program needs **(1)** a vector table at `0x08000000` and **(2)** a reset handler.
- The vector table's first word is the initial SP; the second is the reset handler address **with the Thumb bit set**.
- Build pipeline: `as` → `ld` (with linker script) → `objcopy -O binary` → flash with **OpenOCD** over the on-board CMSIS-DAP probe.
- The `KEEP(...)` directive prevents dead-stripping of the vector table.
- **F5 in VS Code** does the whole thing — build, flash, halt at `reset_handler`. Set breakpoints in `main.s`, single-step with **F10**, watch every register update live in the *CPU Core Register* panel.

---

➡️ **Next:** [Session 05 — Registers and the Thumb ISA](../05-registers-and-thumb/)
