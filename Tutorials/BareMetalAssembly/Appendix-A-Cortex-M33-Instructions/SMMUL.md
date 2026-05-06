# SMMUL — Signed 32×32 multiply, return the top 32 bits of the 64-bit product.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMMUL <Rd>, <Rn>, <Rm>
```

**When you'd actually use this:** SMMUL is the one-instruction answer to **Q31 × Q31 → Q31** fixed-point multiply. In Q1.31, both operands sit in `[-1.0, +1.0)` encoded as 32-bit signed integers; the true product is 64 bits in Q2.62, and the **upper 32 bits** are exactly the Q1.31 answer (one sign-bit duplication, then 31 fraction bits). That's literally what SMMUL returns: `(Rn × Rm) >> 32`, sign-correct, in one register and one cycle. Without SMMUL you'd write `SMULL r0, r1, Rn, Rm; mov result, r1` — same speed but it burns a second register on the throwaway lower half. Reach for SMMUL whenever you're scaling a Q31 sample by a Q31 coefficient (volume control, biquad coefficient multiply, lookup-table interpolation weight) and you don't care about half-LSB rounding bias.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | R0–R12, LR; not PC/SP |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |

## Operation (pseudocode)

```text
prod64 = SInt(Rn) * SInt(Rm)
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
| T1 | 32-bit | `SMMUL` Rd, Rn, Rm |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

`Q` is **not** updated by this family — the result is always the top 32 bits of a 64-bit signed product, which can never overflow.

## Example

### Example 1 — Q31 × Q31 sanity check (0.5 × 0.5 = 0.25)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMMUL demo: Q31 * Q31 -> Q31 (truncated)
    ldr     r1, =0x40000000     @ 0.5 in Q31
    ldr     r2, =0x40000000     @ 0.5 in Q31
    smmul   r0, r1, r2          @ r0 = top32(0.5*0.5 << 32) = 0x10000000 (= 0.25 in Q31)
loop:
    b   loop
```

**Walkthrough:**

1. `smmul` is the workhorse Q31 multiply: it gives you `(Rn * Rm) >> 32` in a single cycle.
2. Note the 1-bit loss vs. true Q31×Q31: result is `Q31_a * Q31_b` rounded **down** to Q31. Use `SMMULR` if you want the rounded form.

### Example 2 — Q31 audio sample × Q31 gain (volume control)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Apply a Q31 gain (~0.7071 = -3 dB) to a Q31 audio sample.
    ldr     r1, =0x5A827999     @ gain  ~ 0.70710678 in Q31
    ldr     r2, =0x6ED9EBA1     @ sample ~ 0.86602540 in Q31 (e.g. mid-amplitude tone)
    smmul   r0, r1, r2          @ r0 = top32(gain * sample) -> ~0.6124 in Q31
loop:
    b   loop
```

**Walkthrough:**

1. A volume knob is just a Q31 gain scalar; each PCM sample is a Q31 number. `smmul` scales the sample in one cycle.
2. The result lands directly in Q31, ready to write back to a DAC FIFO — no shifting, no narrowing, no register pair.
3. If you ran this in a 48 kHz audio loop, every sample costs **one** instruction. The `SMULL`-based alternative is the same cycle count but uses two destination registers, which matters when you're juggling left/right channels in a tight loop.

## See also

- [SMMLA](SMMLA.md) — non-rounding Q31 multiply-accumulate
- [SMMLAR](SMMLAR.md) — rounding Q31 multiply-accumulate
- [SMMLS](SMMLS.md) — non-rounding Q31 multiply-subtract
- [SMMLSR](SMMLSR.md) — rounding Q31 multiply-subtract
- [SMMULR](SMMULR.md) — rounding Q31 multiply
- [SMULL](SMULL.md) — full 64-bit signed product (no top-32 shortcut)
- [SMLAL](SMLAL.md) — 64-bit signed multiply-accumulate

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMMUL*.
