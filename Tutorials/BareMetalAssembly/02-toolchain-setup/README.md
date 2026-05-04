# Session 02 — macOS toolchain setup (with VS Code debugging)

> **Goal:** install everything we need (assembler, linker, debugger, flasher), wire it all into **VS Code** so you can hit ▶ to build and 🐞 to debug with real breakpoints, and prove it works by assembling and inspecting a do-nothing program.

You'll do this once. Future sessions assume these tools are on your `$PATH`.

---

## How the Nano Matter is debugged

Before we install anything, here's the actual data path between your Mac and the EFR32MG24:

```
   ┌─────────┐  USB-C   ┌──────────────┐  SWD  ┌──────────────┐
   │  macOS  │ ───────▶ │   ATSAMD11   │ ────▶ │  EFR32MG24   │
   │ openocd │          │  (CMSIS-DAP) │       │  Cortex-M33  │
   └─────────┘          └──────────────┘       └──────────────┘
        ▲                        ▲
        │                        │
   talks GDB-RSP             on-board USB
   on TCP :3333              bridge running
                             CMSIS-DAP firmware
```

Two important consequences:

1. **No external probe is needed.** The little ATSAMD11 chip on the back of the board is a debug probe. You only ever plug in one USB-C cable.
2. **The probe is CMSIS-DAP, not Segger J-Link.** This means our flasher / debugger is **OpenOCD**, *not* `JLinkExe` / `JLinkGDBServer`. Internally, OpenOCD speaks CMSIS-DAP to the SAMD11, the SAMD11 speaks SWD to the EFR32MG24, and you get a GDB server out the other end on port `3333`.

> **Aside (optional probe):** You *can* attach an external Segger J-Link probe to the Nano Matter's SWD pads if you really want one. Everything in this series will work either way — only the OpenOCD config files / the GDB-server port change. The default workflow assumes the on-board CMSIS-DAP because that's what the board ships with.

---

## What we're installing

The full bare-metal stack we'll use through the rest of this series:

| Tool | What it does | Why we need it |
|---|---|---|
| `arm-none-eabi-as` | Assembler | Turns `.s` files into `.o` object files |
| `arm-none-eabi-ld` | Linker | Combines `.o` files + a linker script into a final `.elf` |
| `arm-none-eabi-gcc` | C compiler driver | Front-end for the whole toolchain (we use `as`/`ld` directly, but `gcc` ships them) |
| `arm-none-eabi-objcopy` | Object copier | Strips the `.elf` down to a raw `.bin` we can flash |
| `arm-none-eabi-objdump` / `nm` / `readelf` | Inspectors | Let us look at what we just built |
| `arm-none-eabi-gdb` | Debugger | Steps through code on the real chip (Sessions 11 & 12) |
| **`openocd`** | Flasher **and** GDB server | Talks to the on-board CMSIS-DAP probe, programs flash, exposes GDB on `:3333` |
| **VS Code** + **Cortex-Debug** + **C/C++** + **ARM** extensions | IDE | Editor, build tasks, **breakpoints, register & memory views, single-step, watch** |

> **Jargon:** **arm-none-eabi** is the name of the cross-toolchain we use. *arm* = target architecture. *none* = no operating system on the target. *eabi* = the binary calling convention. Every tool name starts with this prefix.

> **Jargon:** **CMSIS-DAP** = Arm's vendor-neutral debug-probe protocol. **SWD** = Serial Wire Debug, the 2-wire signalling between probe and target. **OpenOCD** = "Open On-Chip Debugger", an open-source program that bridges the two and exposes a GDB server.

---

## Step 1 — install Homebrew

If you don't already have it, open **Terminal.app** and run:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the on-screen instructions to add `brew` to your shell. Verify:

```sh
brew --version       # → Homebrew 4.x.x
```

---

## Step 2 — install the GNU Arm toolchain

```sh
brew install --cask gcc-arm-embedded
```

This installs all the `arm-none-eabi-*` tools at once. Verify:

```sh
arm-none-eabi-gcc --version
arm-none-eabi-as  --version
arm-none-eabi-ld  --version
arm-none-eabi-gdb --version
```

You should see something like `arm-none-eabi-gcc (Arm GNU Toolchain ...) 13.x.x`.

> **Gotcha:** `arm-none-eabi-gdb` on macOS sometimes needs Python to be available. If `gdb --version` complains about a missing `libpython`, install it with `brew install python@3.11` and try again.

> **Where did it install?** `brew --prefix gcc-arm-embedded` will tell you. The binaries live under `<prefix>/bin/`. We'll need this path for VS Code in a moment.

---

## Step 3 — install OpenOCD (Silicon Labs build)

This is the part that surprised me when I first tried it: **vanilla Homebrew `openocd` does not know how to program the EFR32MG24's flash.** It can connect via CMSIS-DAP, but the bundled `target/efm32.cfg` doesn't recognise the chip's Series-2 flash controller, so `program ...` fails. The Arduino IDE works around this by shipping a *forked* OpenOCD with a custom `target/efm32s2_g23.cfg` script — and that's the one we'll use.

The easiest way to install it is to install the **Silicon Labs Arduino core** once via the Arduino IDE. The IDE downloads the right OpenOCD as part of the core install. After that, you can throw the IDE away and just use the OpenOCD binary it left behind.

1. Install the Arduino IDE if you don't have it: <https://www.arduino.cc/en/software>.
2. Open it, go to **Boards Manager** (left sidebar), search **"Silicon Labs"**, and install the Silicon Labs core.
3. Quit the IDE. The forked OpenOCD now lives at:
   ```
   ~/Library/Arduino15/packages/SiliconLabs/tools/openocd/0.12.0-arduino1-static/
   ```

> **Why not vanilla Homebrew openocd?** If you're curious, run `openocd -f interface/cmsis-dap.cfg -f target/efm32.cfg`. It connects fine, but `program main.elf` fails with a flash-driver error because OpenOCD's upstream `efm32.cfg` doesn't ship the EFR32MG24 (xG24 / "g23") flash bits. The Silicon Labs fork patches that in.

### Verify the install

```sh
SILABS_OOCD=~/Library/Arduino15/packages/SiliconLabs/tools/openocd/0.12.0-arduino1-static
"$SILABS_OOCD/bin/openocd" --version
ls "$SILABS_OOCD/share/openocd/scripts/target/efm32s2_g23.cfg"
```

You should see the OpenOCD banner and a path to `efm32s2_g23.cfg`. The Makefile in every code session sets `SILABS_OOCD` to that path automatically.

### Plug in the board and confirm OpenOCD can see it

Connect the Nano Matter via USB-C. **Use a known-data cable** — a power-only USB-C cable will look identical and silently not enumerate the USB device. Then:

```sh
"$SILABS_OOCD/bin/openocd" \
  -s "$SILABS_OOCD/share/openocd/scripts" \
  -f interface/cmsis-dap.cfg \
  -f target/efm32s2_g23.cfg
```

You should see something like:

```
Open On-Chip Debugger 0.12.0+dev-...
Info : CMSIS-DAP: SWD supported
Info : CMSIS-DAP: FW Version = ...
Info : SWD DPIDR 0x6ba02477
Info : [efm32s2.cpu] Cortex-M33 ...
Info : Listening on port 3333 for gdb connections
```

🎉 — OpenOCD is talking to the chip. Hit **Ctrl-C** to stop it for now.

### Troubleshooting "unable to find a matching CMSIS-DAP device"

This means the macOS USB stack isn't seeing the on-board probe at all. OpenOCD never gets to send a single byte. Things to try, in order:

1. **Replace the USB-C cable.** Use one you've successfully used for data before (e.g. with a phone). Power-only cables are the #1 cause.
2. **Plug directly into the Mac**, not through a hub or dock.
3. **Check that the Mac actually sees a USB device:**
   ```sh
   ioreg -p IOUSB -l | grep -E '"USB Product Name"|"USB Vendor Name"'
   ```
   You should see an entry mentioning *Silicon Labs*, *Arduino*, *CMSIS-DAP*, or *EFM32*. If nothing matches, the board isn't enumerating — the OS is the problem, not OpenOCD.
4. **Check serial-port enumeration:**
   ```sh
   ls /dev/cu.usbmodem*
   ```
   The Nano Matter's CDC serial port appears here when the chip is alive. Missing means the EFR32MG24 isn't running — try pressing the reset button.
5. **Try the `hid` backend explicitly.** Cortex-Debug / OpenOCD on macOS can be picky about which CMSIS-DAP transport is used. Add `-c "cmsis_dap_backend hid"` after the interface config.
6. **Inspect with USB Prober** (built into Apple's "Additional Tools for Xcode") to see whether macOS is failing to fully attach the device.

---

## Step 4 — sanity check from the command line

Before we touch VS Code, let's prove the toolchain works. Make a scratch folder anywhere:

```sh
mkdir -p ~/nano-matter-scratch && cd ~/nano-matter-scratch
```

Create `hello.s`:

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb

    .text
    .global _start
_start:
    nop
    nop
    b       _start
```

> **Jargon:** **`nop`** = "no operation". The CPU does nothing for one cycle. Useful for tutorials and for letting the debugger park on a known instruction.

Assemble, link, and disassemble:

```sh
arm-none-eabi-as -mcpu=cortex-m33 -mthumb hello.s -o hello.o
arm-none-eabi-ld -e _start -Ttext=0x08000000 hello.o -o hello.elf
arm-none-eabi-objdump -d hello.elf
```

Expected output:

```
hello.elf:     file format elf32-littlearm

Disassembly of section .text:

08000000 <_start>:
 8000000:       bf00            nop
 8000002:       bf00            nop
 8000004:       e7fc            b.n     8000000 <_start>
```

🎉 **You have a real ARM Thumb-2 binary.** Two no-ops and a backwards branch — three instructions, six bytes. From now on, this loop ("nop nop branch backwards") is our minimum viable program.

> **Try it:** run `arm-none-eabi-objdump -h hello.elf` to see the section headers. Notice `.text` lives at `0x08000000` — exactly where flash starts on our chip.

> **Try it:** run `arm-none-eabi-readelf -h hello.elf`. The `Flags:` line should mention `Tag_THUMB_ISA_use`. That's how the chip knows it's running Thumb code.

### What the flags mean

```
arm-none-eabi-as -mcpu=cortex-m33 -mthumb hello.s -o hello.o
```

- `-mcpu=cortex-m33` — tells the assembler "this code is for a Cortex-M33". It accepts/rejects instructions accordingly (e.g. `wfi` is fine, classic ARM `swp` is not).
- `-mthumb` — Thumb encoding only. On a Cortex-M chip you always want this. The CPU literally cannot decode classic 32-bit ARM mode.

```
arm-none-eabi-ld -e _start -Ttext=0x08000000 hello.o -o hello.elf
```

- `-e _start` — the **entry point** symbol. The first instruction the chip executes after reset. We'll replace this with a proper vector table in Session 4.
- `-Ttext=0x08000000` — place the `.text` section starting at flash. On EFR32MG24, flash starts at `0x08000000`.

We'll bake all of these into a `Makefile` in Session 4 so you never type them again.

---

## Step 5 — install VS Code

Either download from <https://code.visualstudio.com/> or:

```sh
brew install --cask visual-studio-code
```

Make sure the `code` command is on your `$PATH` (in VS Code: **⌘⇧P → "Shell Command: Install 'code' command in PATH"**).

### Required extensions

Install these three:

| Extension | ID | Why |
|---|---|---|
| **C/C++** | `ms-vscode.cpptools` | Editor smarts for `.c`/`.h` (we'll use a tiny bit later) |
| **Cortex-Debug** | `marus25.cortex-debug` | The hero — graphical debugging of Cortex-M chips, integrates with OpenOCD |
| **ARM** | `dan-c-underwood.arm` | Syntax highlighting for `.s` / `.S` ARM assembly |

From the command line:

```sh
code --install-extension ms-vscode.cpptools
code --install-extension marus25.cortex-debug
code --install-extension dan-c-underwood.arm
```

> **Cortex-Debug** wraps `arm-none-eabi-gdb` and `openocd` and gives you breakpoints, the **Cortex Peripherals** view (live register values for every peripheral!), and a memory inspector. This is the single biggest quality-of-life win you'll get in this series.

---

## Step 6 — configure VS Code for ARM bare-metal debugging

VS Code looks for a `.vscode/` folder in whichever folder you open. We'll create one inside a session folder so each session is self-contained. Open the **Session 04** folder when it exists — for now just create the files in advance under `Tutorials/BareMetalAssembly/04-first-program/.vscode/` (Session 4 ships them too):

### `.vscode/settings.json`

```jsonc
{
  // Tell the C/C++ extension where the cross-compiler lives so it can resolve headers.
  // Adjust if `brew --prefix gcc-arm-embedded` reports a different path.
  "C_Cpp.default.compilerPath": "/opt/homebrew/bin/arm-none-eabi-gcc",
  "C_Cpp.default.intelliSenseMode": "linux-gcc-arm",
  "files.associations": {
    "*.s": "arm",
    "*.S": "arm",
    "*.ld": "linkerscript"
  },
  // Cortex-Debug needs to know which GDB to launch and where OpenOCD lives.
  "cortex-debug.armToolchainPath": "/opt/homebrew/bin",
  "cortex-debug.gdbPath": "/opt/homebrew/bin/arm-none-eabi-gdb",
  "cortex-debug.openocdPath": "/opt/homebrew/bin/openocd"
}
```

> **Apple Silicon vs. Intel:** Homebrew on Apple Silicon installs to `/opt/homebrew`; on Intel Macs it's `/usr/local`. Run `brew --prefix` to see yours, then adjust the paths above.

### `.vscode/tasks.json` — build / clean / flash from the editor

```jsonc
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "build",
      "type": "shell",
      "command": "make",
      "group": { "kind": "build", "isDefault": true },
      "problemMatcher": ["$gcc"]
    },
    {
      "label": "clean",
      "type": "shell",
      "command": "make clean"
    },
    {
      "label": "flash",
      "type": "shell",
      "command": "make flash",
      "dependsOn": "build"
    }
  ]
}
```

Now **⌘⇧B** runs `make`. **⌘⇧P → "Tasks: Run Task" → flash** writes the binary onto the chip.

### `.vscode/launch.json` — the debugger

This is the one that matters. It tells **Cortex-Debug** to spin up `openocd` (CMSIS-DAP + EFM32 config), attach `arm-none-eabi-gdb`, flash your `.elf`, and stop at `reset_handler` so you can step from instruction zero.

```jsonc
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug (CMSIS-DAP / OpenOCD)",
      "type": "cortex-debug",
      "request": "launch",
      "cwd": "${workspaceFolder}",
      "executable": "${workspaceFolder}/main.elf",
      "servertype": "openocd",
      "serverpath": "${env:HOME}/Library/Arduino15/packages/SiliconLabs/tools/openocd/0.12.0-arduino1-static/bin/openocd",
      "searchDir": [
        "${env:HOME}/Library/Arduino15/packages/SiliconLabs/tools/openocd/0.12.0-arduino1-static/share/openocd/scripts"
      ],
      "configFiles": [
        "interface/cmsis-dap.cfg",
        "target/efm32s2_g23.cfg"
      ],
      "runToEntryPoint": "reset_handler",
      "preLaunchTask": "build",
      "showDevDebugOutput": "raw"
    },
    {
      "name": "Attach (CMSIS-DAP / OpenOCD)",
      "type": "cortex-debug",
      "request": "attach",
      "cwd": "${workspaceFolder}",
      "executable": "${workspaceFolder}/main.elf",
      "servertype": "openocd",
      "serverpath": "${env:HOME}/Library/Arduino15/packages/SiliconLabs/tools/openocd/0.12.0-arduino1-static/bin/openocd",
      "searchDir": [
        "${env:HOME}/Library/Arduino15/packages/SiliconLabs/tools/openocd/0.12.0-arduino1-static/share/openocd/scripts"
      ],
      "configFiles": [
        "interface/cmsis-dap.cfg",
        "target/efm32s2_g23.cfg"
      ]
    }
  ]
}
```

Key fields:

- **`servertype: openocd`** — Cortex-Debug starts `openocd` for us (port 3333).
- **`serverpath` + `searchDir`** — point Cortex-Debug at the **Silicon Labs–forked OpenOCD** that the Arduino core installed. Vanilla Homebrew openocd does not include `target/efm32s2_g23.cfg` and cannot program the EFR32MG24's flash.
- **`configFiles`** — the OpenOCD configs to load. `interface/cmsis-dap.cfg` selects the on-board probe; `target/efm32s2_g23.cfg` is the Silicon Labs Series-2 / xG23/xG24 target script that knows how to drive the chip's flash controller.
- **`runToEntryPoint`** — pause execution at this symbol after flashing. For us, that's `reset_handler` (we define it in Session 4).
- **`preLaunchTask: build`** — runs the `build` task in `tasks.json` before each debug session, so you never debug stale binaries.
- **Launch vs. Attach** — *Launch* flashes a fresh binary and resets. *Attach* connects to whatever is already running on the chip (handy if you're chasing a bug that only appears after some uptime).

> **Try it (after Session 4):** with the board plugged in and `main.elf` built, hit **F5**. VS Code starts OpenOCD in a hidden terminal, flashes the chip, and stops at the very first instruction of `reset_handler`. Now **F10** (step over), **F11** (step in), **F5** (continue) — you have a debugger.

---

## Step 7 — the Cortex-Debug debug UI tour

When a debug session is running, look at the left sidebar:

- **Variables** — local C variables (less useful for pure asm, but it shows registers).
- **Watch** — pin expressions like `$pc`, `$sp`, `*0x4003C094` (read a memory-mapped register live).
- **Call Stack** — yes, it works for assembly too, as long as you push/pop `lr` correctly (Session 10).
- **Breakpoints** — click the gutter next to a `.s` line, or right-click for conditional / function breakpoints.
- **🧠 Cortex Registers** — every CPU register: `r0`–`r15`, `xPSR`, `MSP`, `PSP`, `CONTROL`, `PRIMASK`, `FAULTMASK`. Updates live on every halt.
- **🔌 Cortex Peripherals** — *(only when an SVD file is configured — see below)* live, decoded view of every peripheral register on the chip. Click `GPIO → PORTC → DOUT` to see exactly which LED bits are set.
- **Memory** view — open with **⌘⇧P → "Cortex-Debug: View Memory"** and type an address (e.g. `0x20000000`) to scrub through RAM.

### (Optional) Live peripheral view via an SVD file

Silicon Labs ships an **SVD** (System View Description) XML file that names every peripheral register. Drop it next to your `launch.json` and add:

```jsonc
"svdFile": "${workspaceFolder}/EFR32MG24B220F1536IM48.svd"
```

You can find these files inside the Gecko SDK at `platform/Device/SiliconLabs/EFR32MG24/SVD/` — see <https://github.com/SiliconLabs/gecko_sdk>. With this in place, the **Cortex Peripherals** view becomes magic: you can read and write any register from the UI.

---

## A typical debugging session

This is the loop you'll use from Session 4 onward:

1. Open the **session folder** (e.g. `04-first-program/`) in VS Code: `code 04-first-program/`.
2. Edit `main.s`.
3. **F5** to debug. VS Code:
   - runs `make` (`preLaunchTask: build`),
   - launches the Silicon Labs OpenOCD with `interface/cmsis-dap.cfg` + `target/efm32s2_g23.cfg`,
   - launches `arm-none-eabi-gdb` and connects it to `:3333`,
   - flashes the freshly-built `main.elf`,
   - resets the chip and halts at `reset_handler`.
4. Click in the gutter of `main.s` to set breakpoints. Use **F10** / **F11** to step.
5. Inspect **Cortex Registers** to see how each instruction changes `r0`–`r15` and the flags.
6. Stop the session (**⇧F5**) when done. The chip keeps running whatever you last flashed.

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `arm-none-eabi-as: command not found` | Toolchain not on `$PATH`. Open a fresh terminal, or `echo 'export PATH="$(brew --prefix)/bin:$PATH"' >> ~/.zshrc`. |
| `openocd: command not found` (in VS Code) | `cortex-debug.openocdPath` is wrong. Set it to `~/Library/Arduino15/packages/SiliconLabs/tools/openocd/0.12.0-arduino1-static/bin/openocd`. |
| OpenOCD: *"unable to find a matching CMSIS-DAP device"* | macOS USB stack doesn't see the board. Try a different USB-C cable (power-only cables are the #1 cause), plug directly into the Mac (no hub), and run `ioreg -p IOUSB -l \| grep -E '"USB Product Name"'` to confirm enumeration. |
| OpenOCD: *"Can't find target/efm32s2_g23.cfg"* | You're running vanilla Homebrew `openocd`. Use the Silicon Labs–forked binary at `~/Library/Arduino15/.../0.12.0-arduino1-static/bin/openocd` with its bundled scripts dir. |
| OpenOCD: *"target was not examined"* / flash programming fails | You're using `target/efm32.cfg` from upstream OpenOCD. The EFR32MG24 needs `target/efm32s2_g23.cfg` from the Silicon Labs fork. |
| OpenOCD: *"Error: timed out while waiting for target halted"* | Code is stuck in a tight bootloop or an exception. Power-cycle the board, then try with `-c "init; reset halt"` to halt at vector reset before doing anything else. |
| Cortex-Debug: *"Failed to launch OpenOCD"* | Wrong path in `cortex-debug.openocdPath`. Run `which openocd` and paste the result. |
| Breakpoints don't hit | You're debugging stale code. Make sure `preLaunchTask: build` is set, or re-run **build** manually. Also check the Cortex-Debug **gdb-server** terminal for "Flash download skipped" warnings. |
| `arm-none-eabi-gdb` complains about Python | `brew install python@3.11` and re-launch VS Code so it picks up the new env. |
| Flashing seems to succeed but the chip doesn't run your code | Forgot the **Thumb bit** in the vector table? Reset handler address must be `addr | 1` (Session 3 covers this). Or your linker script doesn't place `.vectors` at `0x08000000` — check `arm-none-eabi-objdump -h main.elf`. |

---

## What you should remember

- The toolchain is **`brew install --cask gcc-arm-embedded`** + the **Silicon Labs Arduino core** (which installs the right OpenOCD fork at `~/Library/Arduino15/...`) + VS Code with **C/C++**, **Cortex-Debug**, **ARM** extensions.
- Building an `.elf` is **assemble** (`as`) → **link** (`ld`). Always pass `-mcpu=cortex-m33 -mthumb` to the assembler.
- The Nano Matter's debug probe is the on-board **CMSIS-DAP**, not J-Link. We talk to it with **OpenOCD**, which doubles as the GDB server on `:3333`.
- Standard OpenOCD invocation: `openocd -s "$SILABS_OOCD/share/openocd/scripts" -f interface/cmsis-dap.cfg -f target/efm32s2_g23.cfg` — using the **Silicon Labs–forked openocd**, not Homebrew's.
- VS Code talks to the chip through **Cortex-Debug → OpenOCD → CMSIS-DAP (SAMD11) → Cortex-M33**. Each layer is a separate process you can debug independently.
- `launch.json` is the file you'll come back to most. The two configs that matter are **Launch** (flash + reset + halt) and **Attach** (don't touch the chip, just hook into whatever is running).
- The first session where we flash a real chip is **Session 4**. Until then we just inspect what we build with `objdump`.

---

➡️ **Next:** [Session 03 — Memory map & the vector table](../03-memory-map-and-vector-table/)
