# SMMLAR — Signed 32×32 multiply, add to a 32-bit value placed in the top of a 64-bit field, keep the top 32 bits (with rounding).

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMMLAR <Rd>, <Rn>, <Rm>, <Ra>
```

**When you'd actually use this:** SMMLAR is SMMLA with the **round-half-up** constant baked in — `Rd = Ra + ((Rn × Rm + 0x80000000) >> 32)`. Use it when you're MAC'ing a long Q31 chain — a 64-tap Q31 FIR, a cascade of 4–8 Q31 biquad sections, an LMS adaptive filter that runs for hours — and the per-multiply truncation bias of plain SMMLA would slowly walk your output away from zero. Without SMMLAR you'd need to bias each product by hand: `SMULL`, add `0x80000000` to the 64-bit pair with `ADDS/ADC`, then add the high half to the accumulator — four instructions per tap instead of one. In an audio biquad running at 48 kHz with 5 sections in cascade, that's the difference between an inaudible filter and one with a measurable DC offset.

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
acc64  = (SInt(Ra) << 32) + prod64 + 0x80000000
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
| T1 | 32-bit | `SMMLAR` Rd, Rn, Rm, Ra |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

`Q` is **not** updated by this family — the result is always the top 32 bits of a 64-bit signed product, which can never overflow.

## Example

### Example 1 — rounded Q31 multiply-accumulate

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMMLAR demo: rounded Q31 multiply-accumulate
    ldr     r0, =0x00100000
    ldr     r1, =0x40000000
    ldr     r2, =0x20000000
    smmlar  r0, r1, r2, r0      @ r0 = r0 + top32(b*x + 0x80000000)
loop:
    b   loop
```

**Walkthrough:**

1. Identical to `SMMLA` but rounds the 64-bit product before truncating.
2. Use this in long Q31 cascades to avoid systematic downward bias.

### Example 2 — feed-forward step of a Q31 biquad (b0·x0 + b1·x1 + b2·x2)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Direct Form I biquad numerator: y = b0*x[n] + b1*x[n-1] + b2*x[n-2]
    @ All values Q31. Use SMMLAR so a 5-section cascade doesn't drift.
    ldr     r1, =0x40000000     @ b0
    ldr     r2, =0x20000000     @ x[n]
    ldr     r3, =0x60000000     @ b1
    ldr     r4, =0x10000000     @ x[n-1]
    ldr     r5, =0x40000000     @ b2
    ldr     r6, =0x08000000     @ x[n-2]

    movs    r0, #0              @ Q31 accumulator
    smmlar  r0, r1, r2, r0      @ acc += round(b0 * x[n])
    smmlar  r0, r3, r4, r0      @ acc += round(b1 * x[n-1])
    smmlar  r0, r5, r6, r0      @ acc += round(b2 * x[n-2])
    @ feedback (a1, a2) would be subtracted next with SMMLSR
loop:
    b   loop
```

**Walkthrough:**

1. Three rounded MACs realize the numerator of one biquad section. Each tap rounds independently — that prevents the −0.5 LSB truncation bias from compounding across the cascade.
2. The feedback `−a1·y[n−1] − a2·y[n−2]` slots in next using `SMMLSR` (rounded multiply-subtract).
3. Cost: 3 instructions + 0 scratch registers per numerator. The `SMULL`-based equivalent is ~12 instructions and a 64-bit accumulator pair.

## See also

- [SMMLA](SMMLA.md) — non-rounding Q31 multiply-accumulate
- [SMMLS](SMMLS.md) — non-rounding Q31 multiply-subtract
- [SMMLSR](SMMLSR.md) — rounding Q31 multiply-subtract
- [SMMUL](SMMUL.md) — non-rounding Q31 multiply
- [SMMULR](SMMULR.md) — rounding Q31 multiply
- [SMULL](SMULL.md) — full 64-bit signed product (no top-32 shortcut)
- [SMLAL](SMLAL.md) — 64-bit signed multiply-accumulate

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMMLAR*.
