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

**When you'd actually use this** lets you grab the runtime address of a nearby label without spending a literal-pool word. Hand-written code reaches for it when populating a small jump table, fetching a `.word`/`.byte` constant out of `.text`, or pointing at a string sitting in flash. The Cortex-M boot files use it to load addresses for vector-table fix-ups before the linker symbols are otherwise reachable. The alternative — `LDR Rd, =label` — costs an extra word in the literal pool and an indirect memory load, so `ADR` is strictly cheaper when the label is in range.

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

### Example 1 — Forward jump table and string

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

### Example 2 — Tiny indexed dispatch table

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    movs    r0, #1                  @ pretend this came from a switch
    adr     r1, dispatch
    ldr     r2, [r1, r0, lsl #2]    @ r2 = dispatch[r0]
    blx     r2                      @ call the chosen handler
loop:
    b   loop

    .balign 4
dispatch:
    .word   handler_a + 1           @ Thumb bit set so BLX works
    .word   handler_b + 1

    .thumb_func
handler_a:
    bx  lr
    .thumb_func
handler_b:
    bx  lr
```

**Walkthrough:**

1. `adr r1, dispatch` — PC-relative address of the table; the compiler doesn't need to know where the linker placed it.
2. `ldr r2, [r1, r0, lsl #2]` — scaled indexed load: each entry is 4 bytes, so shift the index left by 2.
3. `blx r2` — indirect call into the chosen function. Because the table words include the Thumb bit, no fix-up is needed.
4. No literal-pool word was emitted — the whole dispatch lives inline in `.text`.

## See also

- [ADD](ADD.md) — the underlying instruction for forward labels
- [SUB](SUB.md) — the underlying instruction for backward labels
- [LDR](LDR.md) — `LDR Rd, =symbol` for far labels via the literal pool

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.7 — *ADR*. Decoded as PC-relative `ADD`/`SUB` (§C2.4.4 / §C2.4.196).
