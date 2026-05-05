# SMMLS — Signed 32×32 multiply, subtract from a 32-bit value placed in the top of a 64-bit field, keep the top 32 bits.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMMLS <Rd>, <Rn>, <Rm>, <Ra>
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | R0–R12, LR; not PC/SP |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |
| `<Ra>` | accumulator GPR | R0–R12, LR |

## Operation (pseudocode)

```text
prod64 = SInt(Rn) * SInt(Rm)                   // signed 32×32 → 64
acc64  = (SInt(Ra) << 32) - prod64
Rd = acc64[63:32]                               // keep top 32 bits
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

This instruction never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMMLS` Rd, Rn, Rm, Ra |

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
    @ SMMLS demo: Q31 multiply-subtract
    ldr     r0, =0x40000000     @ accumulator y
    ldr     r1, =0x20000000
    ldr     r2, =0x20000000
    smmls   r0, r1, r2, r0      @ r0 = r0 - top32(r1*r2)
loop:
    b   loop
```

**Walkthrough:**

1. Subtracts `top32(Rn*Rm)` from `Ra` and stores in `Rd`.
2. Useful for IIR sections of the form `y[n] = x[n] - a*y[n-1]`.

## See also

- [SMMLA](SMMLA.md) — non-rounding Q31 multiply-accumulate
- [SMMLAR](SMMLAR.md) — rounding Q31 multiply-accumulate
- [SMMLSR](SMMLSR.md) — rounding Q31 multiply-subtract
- [SMMUL](SMMUL.md) — non-rounding Q31 multiply
- [SMMULR](SMMULR.md) — rounding Q31 multiply
- [SMULL](SMULL.md) — full 64-bit signed product (no top-32 shortcut)
- [SMLAL](SMLAL.md) — 64-bit signed multiply-accumulate

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMMLS*.
