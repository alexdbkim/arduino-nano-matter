# SMLALDX — Dual signed 16×16 multiply, then sum the two products and accumulate into a 64-bit register pair (with the second operand's halves exchanged).

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLALDX <RdLo>, <RdHi>, <Rn>, <Rm>
```

**When you'd actually use this** — long complex-signal correlations where the imaginary-axis accumulator could outrun 32 bits: radar / SDR matched filters, OFDM channel estimation, long FFTs unrolled into a single accumulator. SMLALDX = SMLADX + 64-bit accumulator. The 32-bit SMLADX saturates after ~64 full-scale complex MACs; the 64-bit version lets you correlate against a 1024-symbol preamble in one straight loop without intermediate scaling.

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
acc64 = acc64 + (p1 + p2)        // 64-bit signed add
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
| T1 | 32-bit | `SMLALDX` RdLo, RdHi, Rn, Rm |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

`Q` is **not** set by this instruction — a 64-bit accumulator cannot overflow on a single dual-product step.

## Example

### Example 1 — Single cross dual-MAC into 64-bit accumulator

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMLALDX demo: long FIR with second operand stored exchanged
    movs    r0, #0
    movs    r1, #0
    ldr     r2, =0x00020001
    ldr     r3, =0x00040003
    smlaldx r0, r1, r2, r3      @ {r1:r0} += 1*3 + 2*4 = 11
loop:
    b   loop
```

**Walkthrough:**

1. Initialise the 64-bit accumulator to zero.
2. `smlaldx` exchanges Rm's halves before the multiplies — choose this when your coefficient pair is laid out the opposite way from your sample pair.
3. No `Q` flag: a 64-bit accumulator can absorb any pair of 16×16 products without overflow until you've issued ~2³² of them.

### Example 2 — Imaginary part of a long complex correlation in r6:r7

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Long matched-filter imaginary accumulator over 2 complex pairs.
    @ Σ Im((a+bi)(c+di)) = Σ (a*d + b*c) accumulated into 64-bit {r7:r6}.
    movs    r6, #0
    movs    r7, #0
    ldr     r4, =0x00020001     @ pair 0: [b0=2 : a0=1]
    ldr     r5, =0x00040003     @ pair 0: [d0=4 : c0=3]
    smlaldx r6, r7, r4, r5      @ {r7:r6} += 1*4 + 2*3 = 10
    ldr     r4, =0x7FFF7FFF     @ pair 1: full-scale samples
    ldr     r5, =0x7FFF7FFF     @ pair 1: full-scale coeffs
    smlaldx r6, r7, r4, r5      @ no risk of 32-bit saturation here
loop:
    b   loop
```

**Walkthrough:**

1. `{r7:r6}` is the 64-bit running imaginary accumulator (RdLo first, RdHi second).
2. SMLALDX swaps Rm's halves — perfect when the coefficient buffer is stored with imag-low / real-high.
3. Two SMLALDXs, two complex MACs, one 64-bit answer — and the very wide accumulator means a 1024-symbol correlation never needs scaling between iterations.

## See also

- [SMLALD](SMLALD.md) — non-exchanged 64-bit dual MAC
- [SMLSLD](SMLSLD.md) — non-exchanged 64-bit dual multiply-subtract
- [SMLSLDX](SMLSLDX.md) — exchanged 64-bit dual multiply-subtract
- [SMLAD](SMLAD.md) — 32-bit accumulator equivalent
- [SMLAL](SMLAL.md) — plain signed 32×32 → 64 multiply-accumulate

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLALDX*.
