# SMULWB — Signed 32-bit × 16-bit (bottom half of `Rm`) multiply; result is the top 32 bits of the 48-bit product.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMULWB <Rd>, <Rn>, <Rm>
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | R0–R12, LR; not PC/SP |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |

## Operation (pseudocode)

```text
prod48 = SInt(Rn) * SInt(Rm[15:0])        // 32×16 → 48-bit signed
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
| T1 | 32-bit | `SMULWB` Rd, Rn, Rm |

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
    @ SMULWB demo: Q31 * Q15 -> Q31 (top 32 of 48 bits)
    ldr     r1, =0x7FFFFFFF     @ Q31 ~ 1.0
    movw    r2, #0x4000         @ Q15 = 0.5
    smulwb  r0, r1, r2          @ r0 ≈ 0x3FFFFFFF (= 0.5 in Q31)
loop:
    b   loop
```

**Walkthrough:**

1. `r1` is a Q31 sample, `r2[15:0]` is a Q15 coefficient.
2. `smulwb` returns bits [47:16] of the 48-bit product, which is the Q31 result of Q31×Q15. This is the building block for fixed-point IIR filters.

## See also

- [SMULBB](SMULBB.md) — halfword MUL variant (BB)
- [SMULBT](SMULBT.md) — halfword MUL variant (BT)
- [SMULTB](SMULTB.md) — halfword MUL variant (TB)
- [SMULTT](SMULTT.md) — halfword MUL variant (TT)
- [SMULWT](SMULWT.md) — halfword MUL variant (WT)
- [SMLAWB](SMLAWB.md) — same product, plus accumulator
- [MUL](MUL.md) — plain 32×32 → low 32 multiply

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMULWB*.
