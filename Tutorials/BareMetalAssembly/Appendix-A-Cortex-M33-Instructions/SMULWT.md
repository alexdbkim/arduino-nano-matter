# SMULWT — Signed 32-bit × 16-bit (top half of `Rm`) multiply; result is the top 32 bits of the 48-bit product.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMULWT <Rd>, <Rn>, <Rm>
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | R0–R12, LR; not PC/SP |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |

## Operation (pseudocode)

```text
prod48 = SInt(Rn) * SInt(Rm[31:16])        // 32×16 → 48-bit signed
Rd = prod48[47:16]                         // top 32 bits = Q31 result
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

This instruction never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMULWT` Rd, Rn, Rm |

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
    @ SMULWT demo: Q31 * Q15 (top half of Rm)
    ldr     r1, =0x7FFFFFFF
    ldr     r2, =0x40000000     @ coeff in top half
    smulwt  r0, r1, r2          @ r0 ≈ 0x3FFFFFFF
loop:
    b   loop
```

**Walkthrough:**

1. Same as `SMULWB` but takes the coefficient from `Rm[31:16]`.
2. Pairs neatly with `SMULWB` when you've packed two Q15 coefficients into one register — pick either with the suffix.

## See also

- [SMULBB](SMULBB.md) — halfword MUL variant (BB)
- [SMULBT](SMULBT.md) — halfword MUL variant (BT)
- [SMULTB](SMULTB.md) — halfword MUL variant (TB)
- [SMULTT](SMULTT.md) — halfword MUL variant (TT)
- [SMULWB](SMULWB.md) — halfword MUL variant (WB)
- [SMLAWT](SMLAWT.md) — same product, plus accumulator
- [MUL](MUL.md) — plain 32×32 → low 32 multiply

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMULWT*.
