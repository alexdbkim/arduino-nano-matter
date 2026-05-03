# Session 02 — macOS toolchain setup

> **Goal:** install everything we need (assembler, linker, debugger, flasher), and prove it works by assembling and linking a do-nothing program.

You'll do this once. Future sessions assume these tools are on your `$PATH`.

---

## What we're installing

| Tool | What it does | Why we need it |
|---|---|---|
| `arm-none-eabi-as` | Assembler | Turns `.s` files into `.o` object files |
| `arm-none-eabi-ld` | Linker | Combines `.o` files + a linker script into a final `.elf` |
| `arm-none-eabi-objcopy` | Object copier | Strips the `.elf` down to a raw `.bin` we can flash |
| `arm-none-eabi-objdump` / `nm` / `readelf` | Inspectors | Let us look at what we just built |
| `arm-none-eabi-gdb` | Debugger | Lets us step through code on the real chip (Session 12) |
| `JLinkExe` | Flasher | Writes our `.bin` into the chip's flash via USB |
| `JLinkGDBServer` | Debug bridge | Connects GDB to the J-Link OB on the board |

> **Jargon:** **arm-none-eabi** is the name of the cross-toolchain we use. "arm" = target architecture. "none" = no operating system on the target. "eabi" = the binary calling convention. Every tool name starts with this prefix.

---

## Step 1 — install Homebrew (if you don't have it)

Open **Terminal** and run:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Verify:

```sh
brew --version
```

---

## Step 2 — install the GNU Arm toolchain

```sh
brew install --cask gcc-arm-embedded
```

> **Gotcha:** You may also see a formula called `arm-none-eabi-gcc`. The cask above is the one Arm officially distributes and is the easiest to keep current.

Verify:

```sh
arm-none-eabi-gcc --version
arm-none-eabi-as  --version
arm-none-eabi-ld  --version
```

You should see something like `arm-none-eabi-gcc (Arm GNU Toolchain ...) 13.x.x`.

---

## Step 3 — install Segger J-Link tools

The Nano Matter has a built-in **J-Link OB** debugger. We talk to it with Segger's tools:

```sh
brew install --cask segger-jlink
```

Verify (don't worry that no chip is connected yet):

```sh
JLinkExe -? | head
```

You should see Segger's banner printed.

---

## Step 4 — sanity check: assemble a do-nothing program

Make a scratch folder anywhere:

```sh
mkdir -p ~/nano-matter-scratch && cd ~/nano-matter-scratch
```

Create a file `hello.s` with this exact content:

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

> **Jargon:** **`nop`** = "no operation". The CPU does nothing for one cycle. Useful for tutorials.

Now assemble and link it:

```sh
arm-none-eabi-as -mcpu=cortex-m33 -mthumb hello.s -o hello.o
arm-none-eabi-ld -e _start -Ttext=0x08000000 hello.o -o hello.elf
arm-none-eabi-objdump -d hello.elf
```

The last command should print something like:

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

---

## What's `_start`?

When the linker builds an executable it needs to know which symbol is the **entry point**. We told it `-e _start`. In Session 4 we'll move this into a proper linker script so we don't have to type it on the command line every time.

---

## A note about the Cortex-M33 flag

Look at the `as` command above:

```
arm-none-eabi-as -mcpu=cortex-m33 -mthumb hello.s -o hello.o
```

- `-mcpu=cortex-m33` tells the assembler "this code is for a Cortex-M33". It then accepts/rejects instructions accordingly.
- `-mthumb` says "Thumb encoding only". On a Cortex-M chip you always want this.

We'll bake both into a `Makefile` in Session 4 so you never type them again.

---

## What you should remember

- The whole toolchain is `brew install --cask gcc-arm-embedded` + `brew install --cask segger-jlink`.
- Building an `.elf` is: **assemble** (`as`) → **link** (`ld`).
- We always pass `-mcpu=cortex-m33 -mthumb` to the assembler.
- The first session where we flash a real chip is Session 4. Until then we just inspect what we build with `objdump`.

---

➡️ **Next:** [Session 03 — Memory map & the vector table](../03-memory-map-and-vector-table/)
