# SMLSLDX — Dual signed 16×16 multiply, then difference the two products and accumulate into a 64-bit register pair (with the second operand's halves exchanged).

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLSLDX <RdLo>, <RdHi>, <Rn>, <Rm>
```

**When you'd actually use this** — long-running conjugate-correlation kernels where the cross-difference `a·d − b·c` (the imag axis of `(a+bi)(c−di)` or DCT-IV butterfly term) needs more than 32 bits of headroom. Typical use cases: long matched filters in OFDM receivers, beamformer cross-spectrum estimators, and high-Q biquad chains. Without the 64-bit form you'd saturate at full scale after ~64 taps and have to interleave shifts.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<RdLo>` | low 32 bits of 64-bit accumulator (read+written) | R0–R12, LR; must differ from `<RdHi>` |
| `<RdHi>` | high 32 bits of 64-bit accumulator (read+written) | R0–R12, LR; must differ from `<RdLo>` |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |

## Operation (pseudocode)

```text
p1 = SInt(Rn[15:0])  * SInt(Rm[31:16])
p2 = SInt(Rn[31:16]) * SInt(Rm[15:0])
acc64 = (SInt(RdHi) << 32) | UInt(RdLo)
acc64 = acc64 + (p1 - p2)        // 64-bit signed add
RdLo = acc64[31:0]
RdHi = acc64[63:32]
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

This instruction never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMLSLDX` RdLo, RdHi, Rn, Rm |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

`Q` is **not** set by this instruction — a 64-bit accumulator cannot overflow on a single dual-product step.

## Example

### Example 1 — Single cross-difference into 64-bit accumulator

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMLSLDX demo: cross-difference into 64-bit accumulator
    movs    r0, #0
    movs    r1, #0
    ldr     r2, =0x00020001
    ldr     r3, =0x00040003
    smlsldx r0, r1, r2, r3      @ {r1:r0} += 1*4 - 2*3 = -2
loop:
    b   loop
```

**Walkthrough:**

1. Initialise the 64-bit accumulator.
2. `smlsldx` does `Rn[lo]·Rm[hi] - Rn[hi]·Rm[lo]` and adds it into `{RdHi:RdLo}`.

### Example 2 — Long conjugate-correlation imaginary 64-bit accumulator

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Σ (a_k d_k - b_k c_k) — imag part of conjugate dot product — into {r5:r4}.
    movs    r4, #0
    movs    r5, #0
    ldr     r0, =0x00020001     @ pair 0: [b=2 : a=1]
    ldr     r1, =0x00040003     @ pair 0: [d=4 : c=3]
    smlsldx r4, r5, r0, r1      @ {r5:r4} += 1*4 - 2*3 = -2
    ldr     r0, =0x7FFF8000     @ pair 1: extreme signed lanes
    ldr     r1, =0x80007FFF     @ pair 1: extreme signed lanes
    smlsldx r4, r5, r0, r1      @ wide accumulator absorbs near-overflow
loop:
    b   loop
```

**Walkthrough:**

1. `{r5:r4}` holds the 64-bit imaginary-axis running sum.
2. Each SMLSLDX exchanges Rm's halves before multiplying, then subtracts the high-lane product — exactly the cross-difference needed for conjugate correlation.
3. With Q15 inputs at full scale each tap can produce ±2³⁰; the 64-bit accumulator gives ~2³³ taps of headroom — more than enough for any practical wireless preamble length.

## See also

- [SMLALD](SMLALD.md) — non-exchanged 64-bit dual MAC
- [SMLALDX](SMLALDX.md) — exchanged 64-bit dual MAC
- [SMLSLD](SMLSLD.md) — non-exchanged 64-bit dual multiply-subtract
- [SMLAD](SMLAD.md) — 32-bit accumulator equivalent
- [SMLAL](SMLAL.md) — plain signed 32×32 → 64 multiply-accumulate

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLSLDX*.
