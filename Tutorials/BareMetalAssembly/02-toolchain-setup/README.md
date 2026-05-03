# Session 02 — macOS toolchain setup (with VS Code debugging)

> **Goal:** install everything we need (assembler, linker, debugger, flasher), wire it all into **VS Code** so you can hit ▶ to build and 🐞 to debug with real breakpoints, and prove it works by assembling and inspecting a do-nothing program.

You'll do this once. Future sessions assume these tools are on your `$PATH`.

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
| `JLinkExe` | Flasher | Writes our `.bin` into the chip's flash via USB |
| `JLinkGDBServer` | Debug bridge | Connects GDB (and VS Code) to the J-Link OB on the board |
| **VS Code** + **Cortex-Debug** + **C/C++** extensions | IDE | Editor, build tasks, **breakpoints, register & memory views, single-step, watch** |

> **Jargon:** **arm-none-eabi** is the name of the cross-toolchain we use. *arm* = target architecture. *none* = no operating system on the target. *eabi* = the binary calling convention. Every tool name starts with this prefix.

> **Heads up — debug bridge:** The exact debug-probe firmware shipped on the on-board ATSAMD11/D14A chip varies by Nano Matter revision. Most boards ship with a J-Link OB image, which is what these instructions assume. If your board enumerates as a CMSIS-DAP probe instead, you'll use OpenOCD or pyOCD in place of `JLinkExe` / `JLinkGDBServer` — the shape of the workflow is identical, only the tool names change. Plug the board in and run `system_profiler SPUSBDataType | grep -A 4 -i 'segger\|cmsis\|j-link'` to find out.

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

## Step 3 — install the Segger J-Link tools

The Nano Matter has a J-Link OB-class debugger built in. Install Segger's tools:

```sh
brew install --cask segger-jlink
```

This adds two commands we care about:

- `JLinkExe` — interactive flasher / register-poker.
- `JLinkGDBServer` — a daemon that exposes the J-Link OB to GDB over TCP port `2331`. **VS Code talks to this through the Cortex-Debug extension.**

Verify:

```sh
JLinkExe -? 2>&1 | head -3
JLinkGDBServer -? 2>&1 | head -3
```

You should see Segger's banner from each.

> **License:** the macOS J-Link tools are free for use with on-board J-Link OB debuggers like the one on the Nano Matter. Just accept the license prompt the first time you run `JLinkExe`.

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
| **Cortex-Debug** | `marus25.cortex-debug` | The hero — graphical debugging of Cortex-M chips, integrates with J-Link |
| **ARM** | `dan-c-underwood.arm` | Syntax highlighting for `.s` / `.S` ARM assembly |

From the command line:

```sh
code --install-extension ms-vscode.cpptools
code --install-extension marus25.cortex-debug
code --install-extension dan-c-underwood.arm
```

> **Cortex-Debug** wraps `arm-none-eabi-gdb` and `JLinkGDBServer` and gives you breakpoints, the **Cortex Peripherals** view (live register values for every peripheral!), and a memory inspector. This is the single biggest quality-of-life win you'll get in this series.

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
  // Cortex-Debug needs to know which GDB to launch and where to find J-Link tools.
  "cortex-debug.armToolchainPath": "/opt/homebrew/bin",
  "cortex-debug.gdbPath": "/opt/homebrew/bin/arm-none-eabi-gdb",
  "cortex-debug.JLinkGDBServerPath": "/opt/homebrew/bin/JLinkGDBServerCLExe"
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

This is the one that matters. It tells **Cortex-Debug** to spin up `JLinkGDBServer`, attach `arm-none-eabi-gdb`, flash your `.elf`, and stop at `reset_handler` so you can step from instruction zero.

```jsonc
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug (J-Link)",
      "type": "cortex-debug",
      "request": "launch",
      "cwd": "${workspaceFolder}",
      "executable": "${workspaceFolder}/main.elf",
      "servertype": "jlink",
      "device": "EFR32MG24BxxxF1536",
      "interface": "swd",
      "runToEntryPoint": "reset_handler",
      "preLaunchTask": "build",
      "showDevDebugOutput": "raw"
    },
    {
      "name": "Attach (J-Link)",
      "type": "cortex-debug",
      "request": "attach",
      "cwd": "${workspaceFolder}",
      "executable": "${workspaceFolder}/main.elf",
      "servertype": "jlink",
      "device": "EFR32MG24BxxxF1536",
      "interface": "swd"
    }
  ]
}
```

Key fields:

- **`servertype: jlink`** — Cortex-Debug starts `JLinkGDBServer` for us (port 2331).
- **`device`** — exact J-Link device name. `EFR32MG24BxxxF1536` matches the 1536 KB-flash variant on the Nano Matter.
- **`interface: swd`** — Serial Wire Debug, the 2-wire debug protocol Cortex-M chips use.
- **`runToEntryPoint`** — pause execution at this symbol after flashing. For us, that's `reset_handler` (we define it in Session 4).
- **`preLaunchTask: build`** — runs the `build` task in `tasks.json` before each debug session, so you never debug stale binaries.
- **Launch vs. Attach** — *Launch* flashes a fresh binary and resets. *Attach* connects to whatever is already running on the chip (handy if you're chasing a bug that only appears after some uptime).

> **Try it (after Session 4):** with the board plugged in and `main.elf` built, hit **F5**. VS Code starts JLinkGDBServer in a hidden terminal, flashes the chip, and stops at the very first instruction of `reset_handler`. Now **F10** (step over), **F11** (step in), **F5** (continue) — you have a debugger.

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
   - launches `JLinkGDBServer`,
   - launches `arm-none-eabi-gdb` and connects it,
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
| Cortex-Debug error: *"Failed to launch JLinkGDBServer"* | Wrong path in `cortex-debug.JLinkGDBServerPath`. Run `which JLinkGDBServerCLExe` and paste the result. |
| J-Link error: *"Cannot connect to target"* | Board not plugged in / different USB cable / debug probe firmware isn't J-Link. Try `system_profiler SPUSBDataType \| grep -i j-link` to verify. |
| Cortex-Debug error: *"Unknown device EFR32MG24BxxxF1536"* | Update Segger J-Link tools (`brew upgrade --cask segger-jlink`); newer EFR32 device names ship in recent versions. |
| Breakpoints don't hit | You're debugging stale code. Make sure `preLaunchTask: build` is set, or re-run **build** manually. Also check the Cortex-Debug **gdb-server** terminal for "Flash download skipped" warnings. |
| `arm-none-eabi-gdb` complains about Python | `brew install python@3.11` and re-launch VS Code so it picks up the new env. |
| macOS Gatekeeper blocks Segger tools | **System Settings → Privacy & Security → "Allow Anyway"** the first time. |

---

## What you should remember

- The whole toolchain is **`brew install --cask gcc-arm-embedded`** + **`brew install --cask segger-jlink`** + VS Code with **C/C++**, **Cortex-Debug**, **ARM** extensions.
- Building an `.elf` is **assemble** (`as`) → **link** (`ld`). Always pass `-mcpu=cortex-m33 -mthumb` to the assembler.
- VS Code talks to the chip through **Cortex-Debug → JLinkGDBServer → J-Link OB → Cortex-M33**. Each layer is a separate process you can debug independently.
- `launch.json` is the file you'll come back to most. The two configs that matter are **Launch** (flash + reset + halt) and **Attach** (don't touch the chip, just hook into whatever is running).
- The first session where we flash a real chip is **Session 4**. Until then we just inspect what we build with `objdump`.

---

➡️ **Next:** [Session 03 — Memory map & the vector table](../03-memory-map-and-vector-table/)
