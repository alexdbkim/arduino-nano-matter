# RSB — reverse subtract: `Rd = operand2 − Rn`

## Class & availability

- **Class:** Arithmetic
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
RSB{S}{<cond>} {<Rd>,} <Rn>, #<imm>
RSB{S}{<cond>} {<Rd>,} <Rn>, <Rm>{, <shift>}
```

Same as `SUB`, but the operands are swapped: the immediate or `<Rm>` is the minuend, `<Rn>` is the subtrahend. Useful when you want `imm − reg` (you can't put an immediate first in `SUB`) or to negate a value: `RSB Rd, Rn, #0`.

**When you'd actually use this**: RSB is what you reach for when the constant has to come *first* — there is no `SUB Rd, #imm, Rn` syntax. So `255 − x` for colour inversion, `100 − x` for percent-complement, or `LIMIT − x` in saturation logic all compile to a single `RSB`. It's also the canonical negate (`RSB Rd, Rn, #0`, which `NEG` aliases to). Occasionally RSB rescues an immediate that doesn't fit a modified-immediate as `Rn − imm` but does fit as `imm − Rn`. Without RSB you'd waste a `MOV` just to materialise the constant first.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | T1: `R0`–`R7`. T2: `R0`–`R12`. |
| `<Rn>` | subtrahend | same set as `<Rd>` |
| `<Rm>` | minuend (register form) | any low/high register in 32-bit form |
| `#<imm>` | minuend (immediate form) | T2: 12-bit modified immediate |
| `<shift>` | optional shift on `<Rm>` | `LSL`/`LSR`/`ASR`/`ROR` #0–31, or `RRX` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    (result, carry, overflow) = AddWithCarry(NOT(R[n]), operand2, '1')
    R[d] = result
    if S == '1' then
        APSR.N = result<31>
        APSR.Z = IsZeroBit(result)
        APSR.C = carry
        APSR.V = overflow
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | ✓ | – |

Only with the `S` suffix.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `RSBS Rd, Rn, #0` only — the canonical "negate" form |
| T2 | 32-bit | `RSB{S}.W Rd, Rn, #<modified imm>` |
| T2 | 32-bit | `RSB{S}.W Rd, Rn, Rm{, shift}` |

There is **no** `RSB` with an arbitrary 16-bit imm8: only the negate form exists in 16 bits. Other immediates need the 32-bit T2.

## Exceptions / faults

- (none).

## Example

### Example 1 — branchless abs, negate, and `100 − r`

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ RSB demo: take the absolute value of r0 (signed)
    ldr     r0, =-1234
    asrs    r1, r0, #31         @ r1 = sign mask: -1 if negative, 0 if non-negative
    eor     r0, r0, r1
    sub     r0, r0, r1          @ r0 = abs(r0) using the bit-twiddle idiom
    @ alternative single-instruction negate via RSB
    ldr     r2, =42
    rsb     r3, r2, #0          @ r3 = 0 - r2 = -42
    @ subtract from a constant: r5 = 100 - r4
    movs    r4, #25
    rsb     r5, r4, #100        @ r5 = 75
loop:
    b       loop
```

**Walkthrough:**

1. The first three lines are the branchless `abs()` idiom and don't use RSB — included for context.
2. `rsb r3, r2, #0` — negate. Equivalent to `NEG`; in fact `NEG` is a unified-syntax alias for exactly this.
3. `rsb r5, r4, #100` — `r5 = 100 − r4`. You can't write `sub r5, #100, r4`; that's why RSB exists.

### Example 2 — 8-bit colour-channel inversion

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global reset_handler
    .thumb_func
reset_handler:
    movs    r0, #200            @ R channel
    rsb     r1, r0, #255        @ inverted R = 55
    movs    r0, #128            @ G channel
    rsb     r2, r0, #255        @ inverted G = 127
    movs    r0, #64             @ B channel
    rsb     r3, r0, #255        @ inverted B = 191
loop:
    b       loop
```

**Walkthrough:**

1. Each channel inversion is a single `RSB` against the constant `#255`. There is no `SUB Rd, #255, Rn` syntax, so without RSB you'd need a `MOV` + `SUB` pair — twice the instruction count.
2. This same pattern handles any "complement against a constant" — `100 - percent`, `LIMIT - x` for saturation, `MAX - cursor` to compute remaining capacity.
3. `RSB Rd, Rn, #0` is the special case used by `NEG`. The general `RSB Rd, Rn, #imm` extends it to any 12-bit modified immediate.

## See also

- [SUB](SUB.md) — same arithmetic, operands swapped
- [NEG](NEG.md) — alias for `RSBS Rd, Rn, #0`
- [SBC](SBC.md) — extends multi-word subtraction (no `RSC` on Armv8-M)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.143 — *RSB (immediate)*, §C2.4.144 — *RSB (register)*.
