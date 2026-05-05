# SMMULR — Signed 32×32 multiply, return the top 32 bits of the 64-bit product (rounded — `0x80000000` is added before truncation).

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMMULR <Rd>, <Rn>, <Rm>
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | R0–R12, LR; not PC/SP |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |

## Operation (pseudocode)

```text
prod64 = SInt(Rn) * SInt(Rm) + 0x80000000
Rd = prod64[63:32]                              // top 32 bits of signed product
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

This instruction never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMMULR` Rd, Rn, Rm |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

`Q` is **not** updated by this family — the result is always the top 32 bits of a 64-bit signed product, which can never overflow.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMMULR demo: rounded Q31 multiply
    ldr     r1, =0x40000000
    ldr     r2, =0x40000000
    smmulr  r0, r1, r2          @ r0 = top32(0x4000000000000000 + 0x80000000)
loop:
    b   loop
```

**Walkthrough:**

1. Same as `SMMUL` but adds `0x80000000` to the 64-bit product before truncating to the top 32 bits.
2. This is round-half-up rounding for Q31 multiply — preferred when you're feeding a long IIR/biquad cascade and don't want truncation bias.

## See also

- [SMMLA](SMMLA.md) — non-rounding Q31 multiply-accumulate
- [SMMLAR](SMMLAR.md) — rounding Q31 multiply-accumulate
- [SMMLS](SMMLS.md) — non-rounding Q31 multiply-subtract
- [SMMLSR](SMMLSR.md) — rounding Q31 multiply-subtract
- [SMMUL](SMMUL.md) — non-rounding Q31 multiply
- [SMULL](SMULL.md) — full 64-bit signed product (no top-32 shortcut)
- [SMLAL](SMLAL.md) — 64-bit signed multiply-accumulate

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMMULR*.
