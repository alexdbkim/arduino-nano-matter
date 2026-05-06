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

**When you'd actually use this:** SMMULR is SMMUL with **round-half-up** baked in — it adds `0x80000000` to the 64-bit product before discarding the lower 32 bits, so the Q31 result rounds to nearest instead of always truncating toward −∞. That tiny half-LSB shift matters: plain truncation injects a small **negative DC bias** into every multiply, and in a long IIR cascade or a slow-moving control-loop integrator that bias accumulates into an audible (or measurable) offset. Reach for SMMULR in audio EQ biquads, motor-control PID coefficient multiplies, and anywhere your output drifts when you'd expect zero. Without it, the manual round costs an extra `ADDS`/`ADC` pair on a 64-bit product (i.e., `SMULL` then a 64-bit add of `0x80000000` then take the high half) — three instructions and two registers instead of one.

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

### Example 1 — rounded Q31 multiply (0.5 × 0.5)

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

### Example 2 — bias-free DC: rounding kills the truncation drift

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ A small Q31 coefficient * a small Q31 sample — exactly the case where
    @ SMMUL would lose the half-LSB and SMMULR keeps it.
    ldr     r1, =0x00000003     @ tiny Q31 coefficient (3 LSB)
    ldr     r2, =0x55555555     @ ~0.3333 in Q31
    smmul   r3, r1, r2          @ r3 = truncated  -> 0x00000000 (lost!)
    smmulr  r0, r1, r2          @ r0 = rounded    -> 0x00000001 (kept)
loop:
    b   loop
```

**Walkthrough:**

1. The true product `3 × 0x55555555` is `0xFFFFFFFF` (64-bit), whose top 32 bits are `0` and whose bottom-32 MSB is set. Truncation throws away that MSB — `SMMUL` returns 0.
2. `SMMULR` adds `0x80000000` first, which carries into the upper word and gives `1` — the correct rounded Q31 answer.
3. In a 1000-tap filter run at 48 kHz, that "lost half-LSB" per sample is what shows up on a scope as DC offset. Use SMMULR by default in any signal-processing loop; only fall back to SMMUL if you've measured and the bias doesn't matter.

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
