# SMULBT — Signed 16×16 multiply: bottom half of `Rn` × top half of `Rm` → 32-bit `Rd`.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMULBT <Rd>, <Rn>, <Rm>
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | R0–R12, LR; not PC/SP |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |

## Operation (pseudocode)

```text
Rd = SInt(Rn[15:0]) * SInt(Rm[31:16])    // 16×16 → 32 signed
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

This instruction never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMULBT` Rd, Rn, Rm |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMULBT demo: low(Rn) * high(Rm)
    ldr     r1, =0x00007FFF     @ Rn low = 0x7FFF
    ldr     r2, =0x7FFF0000     @ Rm high = 0x7FFF
    smulbt  r0, r1, r2          @ r0 = 0x3FFF0001
loop:
    b   loop
```

**Walkthrough:**

1. `r1`'s low half holds one int16, `r2`'s high half holds another.
2. `smulbt` returns their signed product. Common when one operand is a coefficient packed into the top half of a register.

## See also

- [SMULBB](SMULBB.md) — halfword MUL variant (BB)
- [SMULTB](SMULTB.md) — halfword MUL variant (TB)
- [SMULTT](SMULTT.md) — halfword MUL variant (TT)
- [SMULWB](SMULWB.md) — halfword MUL variant (WB)
- [SMULWT](SMULWT.md) — halfword MUL variant (WT)
- [SMLABT](SMLABT.md) — same product, plus accumulator
- [MUL](MUL.md) — plain 32×32 → low 32 multiply

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMULBT*.
