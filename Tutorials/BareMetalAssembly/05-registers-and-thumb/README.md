# Session 05 — Registers and the Thumb ISA

> **Goal:** learn the small set of CPU registers and instructions you'll use 90% of the time, then write a tiny program that adds three numbers and stores the result in RAM.

We finally get to do *computation*.

---

## Meet the registers

The Cortex-M33 has **16 general-purpose registers**, named `r0` through `r15`. Three of them have special roles:

| Name | Alias | Purpose |
|---|---|---|
| `r0`–`r12` | — | General-purpose. Use freely. |
| `r13` | `sp` | **Stack Pointer** — the top of the stack. |
| `r14` | `lr` | **Link Register** — return address for function calls. |
| `r15` | `pc` | **Program Counter** — the address of the *next* instruction. |

There's also one important non-numbered register:

- `xPSR` (or `PSR`) — the **Program Status Register**. Holds condition flags (N, Z, C, V), interrupt status, and the Thumb bit (always 1 on Cortex-M).

That's it. No segment registers, no floating-point yet, no SIMD. For everything we'll do, those 16 + xPSR are the whole machine.

> **Jargon:** **Condition flags** are bits set by certain arithmetic instructions: **N** (negative), **Z** (zero), **C** (carry), **V** (overflow). Branch instructions like `beq` ("branch if equal") look at these.

---

## A vocabulary of instructions

You only need a small set to do real work. Here's the cheat sheet for this series:

### Move data

```asm
    mov   r0, #42         @ r0 := 42      (small immediates only)
    movw  r0, #0x1234     @ r0 := 0x1234  (lower 16 bits)
    movt  r0, #0xABCD     @ r0[31:16] := 0xABCD
    mov   r1, r0          @ r1 := r0
```

### Load and store memory

```asm
    ldr   r0, [r1]        @ r0 := *(uint32_t*)r1
    ldr   r0, [r1, #4]    @ r0 := *(uint32_t*)(r1 + 4)
    str   r0, [r1]        @ *(uint32_t*)r1 := r0

    ldr   r0, =0x4003C000 @ r0 := 0x4003C000  (assembler trick — see below)
```

> **Why?:** `mov` can only put small constants directly into a register. For full 32-bit values, the assembler uses `ldr Rd, =<value>` which puts the constant into a literal pool nearby and loads it.

### Arithmetic

```asm
    add   r0, r1, r2      @ r0 := r1 + r2
    add   r0, r0, #1      @ r0 := r0 + 1
    sub   r0, r1, #4      @ r0 := r1 - 4
    lsl   r0, r1, #2      @ r0 := r1 << 2  (logical shift left)
    orr   r0, r1, r2      @ r0 := r1 | r2
    and   r0, r1, r2      @ r0 := r1 & r2
    bic   r0, r1, r2      @ r0 := r1 & ~r2 (bit clear)
```

### Compare and branch

```asm
    cmp   r0, #0          @ sets flags from (r0 - 0)
    beq   target          @ branch if Z=1
    bne   target          @ branch if Z=0
    b     target          @ unconditional branch
    bl    func            @ branch with link (call)
    bx    lr              @ branch via register (return)
```

That's enough vocabulary to write almost any program in this series.

---

## The program for this session

We'll compute `7 + 11 + 23 = 41` and store it at the start of RAM. No peripherals yet — pure arithmetic.

See [`main.s`](./main.s). Build it with `make` and inspect the disassembly:

```sh
make disasm
```

You should see something like:

```
reset_handler:
    ldr   r0, =0x20000000        @ pointer to result in RAM
    mov   r1, #7
    mov   r2, #11
    mov   r3, #23
    add   r1, r1, r2             @ r1 = 18
    add   r1, r1, r3             @ r1 = 41
    str   r1, [r0]               @ *0x20000000 = 41
1:  b     1b                     @ spin
```

Flash it, then attach with GDB (Session 12 for the full walkthrough — for now, this works):

```sh
JLinkGDBServer -device EFR32MG24BxxxF1536 -if SWD &
arm-none-eabi-gdb main.elf
(gdb) target remote :2331
(gdb) monitor reset
(gdb) continue
^C
(gdb) x/wx 0x20000000
0x20000000:    0x00000029       ← that's 41 in hex. ✅
```

> **Try it:** change one of the numbers in `main.s`, rebuild, reflash, and verify RAM. You'll see the new sum.

---

## Hand-trace it on paper

Before running, walk through the instructions yourself with a column for each register:

| step | instruction         | r0           | r1 | r2 | r3 |
|------|---------------------|--------------|----|----|----|
| 0    | (start)             | ?            | ?  | ?  | ?  |
| 1    | `ldr r0, =0x20000000` | 0x20000000 | ?  | ?  | ?  |
| 2    | `mov r1, #7`        | 0x20000000   | 7  | ?  | ?  |
| 3    | `mov r2, #11`       | 0x20000000   | 7  | 11 | ?  |
| 4    | `mov r3, #23`       | 0x20000000   | 7  | 11 | 23 |
| 5    | `add r1, r1, r2`    | 0x20000000   | 18 | 11 | 23 |
| 6    | `add r1, r1, r3`    | 0x20000000   | 41 | 11 | 23 |
| 7    | `str r1, [r0]`      | (writes 41 to RAM)         |

Doing this until it feels boring is the **fastest** way to internalise an ISA.

---

## What you should remember

- Cortex-M33 has **r0–r15**, where `r13`=`sp`, `r14`=`lr`, `r15`=`pc`.
- `mov` for small constants, `ldr Rd, =value` for big ones.
- `ldr/str` always go through a register holding the address.
- Comparison flags (`N`, `Z`, `C`, `V`) live in `xPSR` and drive conditional branches like `beq` / `bne`.

---

➡️ **Next:** [Session 06 — Memory-mapped I/O](../06-memory-mapped-io/)
