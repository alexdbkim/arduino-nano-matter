# SMMLSR — Signed 32×32 multiply, subtract from a 32-bit value placed in the top of a 64-bit field, keep the top 32 bits (with rounding).

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMMLSR <Rd>, <Rn>, <Rm>, <Ra>
```

**When you'd actually use this:** SMMLSR is the rounded sibling of SMMLS — `Rd = Ra − ((Rn × Rm + 0x80000000) >> 32)`. Use it for the feedback (pole) taps of long Q31 IIR cascades, where the half-LSB truncation bias of plain SMMLS, multiplied across hundreds of samples per second and several cascaded sections, becomes a measurable DC offset or low-frequency drift. Concretely: every biquad in a 5-section graphic-EQ uses two SMMLSR's for the `-a1·y1 - a2·y2` recurrence. Without SMMLSR you'd round the product manually with a 64-bit `ADDS/ADC` of `0x80000000` then a 64-bit subtract — four instructions and a 64-bit register pair per pole tap, vs. one register and one cycle for SMMLSR.

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
acc64  = (SInt(Ra) << 32) - prod64 + 0x80000000
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
| T1 | 32-bit | `SMMLSR` Rd, Rn, Rm, Ra |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

`Q` is **not** updated by this family — the result is always the top 32 bits of a 64-bit signed product, which can never overflow.

## Example

### Example 1 — rounded Q31 multiply-subtract

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMMLSR demo: rounded Q31 multiply-subtract
    ldr     r0, =0x40000000
    ldr     r1, =0x20000000
    ldr     r2, =0x20000000
    smmlsr  r0, r1, r2, r0      @ r0 = r0 - top32(r1*r2 + 0x80000000)
loop:
    b   loop
```

**Walkthrough:**

1. Rounded form of `SMMLS`. The round constant is added inside the negated product, so the result is `Ra - round(Rn·Rm >> 32)`.

### Example 2 — both feedback poles of a Q31 biquad, rounded

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Direct-Form-I biquad recurrence (rounded):
    @   y[n] = (b0*x0 + b1*x1 + b2*x2) - a1*y[n-1] - a2*y[n-2]
    @ Numerator already in r0.  Now subtract the two poles, rounding each tap.
    ldr     r0, =0x20000000     @ acc = numerator result so far
    ldr     r1, =0x60000000     @ a1
    ldr     r2, =0x10000000     @ y[n-1]
    ldr     r3, =0x30000000     @ a2
    ldr     r4, =0x08000000     @ y[n-2]

    smmlsr  r0, r1, r2, r0      @ acc -= round(a1 * y[n-1])
    smmlsr  r0, r3, r4, r0      @ acc -= round(a2 * y[n-2])
    @ r0 is the new y[n] in Q31, with no truncation bias.
loop:
    b   loop
```

**Walkthrough:**

1. Each pole subtraction rounds the product before subtracting — so a cascade of 5+ biquads stays bias-free.
2. Pair this with three `SMMLAR` for the numerator: a complete rounded Q31 biquad section is **5 instructions** in the hot loop, with the accumulator never leaving a single Q31 register.
3. The round-half-up constant lives entirely inside the instruction; you never have to materialize `0x80000000` in a register.

## See also

- [SMMLA](SMMLA.md) — non-rounding Q31 multiply-accumulate
- [SMMLAR](SMMLAR.md) — rounding Q31 multiply-accumulate
- [SMMLS](SMMLS.md) — non-rounding Q31 multiply-subtract
- [SMMUL](SMMUL.md) — non-rounding Q31 multiply
- [SMMULR](SMMULR.md) — rounding Q31 multiply
- [SMULL](SMULL.md) — full 64-bit signed product (no top-32 shortcut)
- [SMLAL](SMLAL.md) — 64-bit signed multiply-accumulate

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMMLSR*.
