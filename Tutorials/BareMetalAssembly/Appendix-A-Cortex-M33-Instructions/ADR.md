# ADR — load a PC-relative address into a register (synthetic)

## Class & availability

- **Class:** Arithmetic (synthetic / pseudo-instruction)
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
ADR{<cond>} <Rd>, <label>
```

Compute the address of `<label>` (relative to the PC) and put it in `<Rd>`. There is no `ADR` opcode in the machine: the assembler picks one of `ADD Rd, PC, #imm` or `SUB Rd, PC, #imm` depending on whether the label is ahead of or behind the current PC.

`ADR` is the canonical way to take the address of a nearby code label, jump table, or `.byte`/`.word` literal embedded in `.text`. For *far* targets or RAM addresses, use `LDR Rd, =symbol` instead, which expands to a literal-pool load.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | T1: `R0`–`R7`. T2/T3: `R0`–`R12`. |
| `<label>` | code label | Reachable in the immediate range; see below. |

**Reach of the encodings:**

| Variant | Width | Range |
|---------|-------|-------|
| T1 | 16-bit | `ADD Rd, PC, #imm`, `Rd ∈ R0–R7`, imm = `0..1020` (multiple of 4). Forward only. |
| T2 | 32-bit | `SUB Rd, PC, #imm12`, imm = `0..4095`. Backward. |
| T3 | 32-bit | `ADD Rd, PC, #imm12`, imm = `0..4095`. Forward. |

If `<label>` is out of range the assembler reports an error; switch to `LDR Rd, =<label>` (literal pool) for any distance.

## Operation (pseudocode)

```text
if ConditionPassed() then
    base   = Align(PC, 4)            // PC reads as current insn + 4, then aligned
    offset = imm32                   // sign of offset is encoded by ADD vs SUB form
    R[d]   = base + offset           // for ADR-add
    R[d]   = base - offset           // for ADR-sub
```

`PC` reads as **the address of the current instruction + 4**, then word-aligned (low two bits forced to 0). That alignment is the part that bites people: `ADR Rd, label` to a label declared with `.byte` data in between can resolve to an offset that is *not* exactly the difference of the source addresses — always pad with `.balign 4` if you intend to step over it.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never. There is no `ADRS`.

## Encodings

| Variant | Width | Underlying encoding |
|---------|-------|---------------------|
| T1 | 16-bit | `ADD Rd, PC, #imm8 << 2` |
| T2 | 32-bit | `SUB Rd, PC, #imm12` |
| T3 | 32-bit | `ADD Rd, PC, #imm12` |

The disassembler typically shows `ADD Rd, PC, ...` or `SUB Rd, PC, ...`, not `ADR`. Same instruction, different name in the manual vs. in your editor.

## Exceptions / faults

- (none).

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ ADR demo: load the address of a nearby string and a jump-table entry
    adr     r0, message         @ r0 = &message
    adr     r1, jtab            @ r1 = &jtab
    ldr     r2, [r1]            @ r2 = first entry of jtab (a function ptr | 1)

    .balign 4
jtab:
    .word   reset_handler + 1   @ Thumb bit set
    .word   reset_handler + 1
message:
    .asciz  "hi"
    .balign 2
loop:
    b       loop
```

**Walkthrough:**

1. `adr r0, message` — assembles to a forward `ADD Rd, PC, #imm`. The result is the runtime address of `message`, no matter where the linker places the section.
2. `adr r1, jtab` followed by `ldr r2, [r1]` — the standard "PC-relative table" pattern. Because `jtab` words include the Thumb bit (`+ 1`), `r2` is directly callable with `BLX r2`.
3. `.balign 4` before `jtab` is essential: PC is word-aligned during the `ADR`, so the label must be too, or you'll fetch the wrong word.

## See also

- [ADD](ADD.md) — the underlying instruction for forward labels
- [SUB](SUB.md) — the underlying instruction for backward labels
- [LDR](LDR.md) — `LDR Rd, =symbol` for far labels via the literal pool

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.7 — *ADR*. Decoded as PC-relative `ADD`/`SUB` (§C2.4.4 / §C2.4.196).
