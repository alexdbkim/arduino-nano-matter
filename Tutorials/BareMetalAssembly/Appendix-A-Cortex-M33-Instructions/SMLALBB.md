# SMLALBB — Signed 16×16 multiply (bottom half of `Rn` × bottom half of `Rm`); accumulate the 32-bit product into a 64-bit `{RdHi:RdLo}` pair.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLALBB <RdLo>, <RdHi>, <Rn>, <Rm>
```

**When you'd actually use this:** `SMLALBB` is the workhorse when you need a *long-running* signed 16×16 MAC and a 32-bit accumulator just isn't deep enough. The hero here is the 64-bit `{RdHi:RdLo}` pair — it gives you 32 extra bits of headroom over any single Q15 product, so you can sum **millions** of taps before risking overflow. Real-world spots: long FIR filters for room-correction EQ on the Nano Matter, sensor-fusion integrators that run for hours without a reset, and per-frame energy summers in audio-feature pipelines that only square-root at the very end. Without `SMLALBB`, accumulating 1024 Q15 taps in 32 bits would clip well before the loop ends; rolling your own 64-bit MAC out of `SMULBB` + `ADDS` + `ADC` costs 3–4 instructions per tap instead of just one.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<RdLo>` | low 32 bits of 64-bit accumulator (read+written) | R0–R12, LR; must differ from `<RdHi>` |
| `<RdHi>` | high 32 bits of 64-bit accumulator (read+written) | R0–R12, LR; must differ from `<RdLo>` |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |

## Operation (pseudocode)

```text
prod32 = SInt(Rn[15:0]) * SInt(Rm[15:0])
acc64  = (SInt(RdHi) << 32) | UInt(RdLo)
acc64  = acc64 + prod32
RdLo   = acc64[31:0]
RdHi   = acc64[63:32]
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

This instruction never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMLALBB` RdLo, RdHi, Rn, Rm |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

`Q` is **not** updated — a single 16×16 product can't overflow a 64-bit accumulator.

## Example

### Example 1 — single-tap 64-bit MAC seed

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMLALBB demo: long-running biquad, 16-bit coeffs, 64-bit accumulator
    movs    r0, #0              @ RdLo
    movs    r1, #0              @ RdHi
    movw    r2, #0x7FFF         @ sample (low half)
    movw    r3, #0x7FFF         @ coeff  (low half)
    smlalbb r0, r1, r2, r3      @ {r1:r0} += sample * coeff
loop:
    b   loop
```

**Walkthrough:**

1. Initialise the 64-bit accumulator pair `{r1:r0}` to zero.
2. Drop one Q15 sample and one Q15 coefficient into the bottom halves of `r2` and `r3`.
3. `smlalbb` adds their signed product into the 64-bit accumulator. Run thousands of taps without ever needing to saturate — the 64-bit pair has 32 bits of headroom over a 16×16 product.

### Example 2 — long FIR filter body, accumulating into `{r4:r3}`

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  fir_smlalbb
    .thumb_func
fir_smlalbb:
    @ r0 = int16 sample ptr, r1 = int16 coeff ptr, r2 = N taps
    push    {r4-r6, lr}
    movs    r3, #0              @ acc lo
    movs    r4, #0              @ acc hi
1:  ldrsh   r5, [r0], #2        @ next sample, sign-extended into low half of r5
    ldrsh   r6, [r1], #2        @ next coeff, sign-extended into low half of r6
    smlalbb r3, r4, r5, r6      @ {r4:r3} += (int16)r5 * (int16)r6
    subs    r2, r2, #1
    bne     1b
    @ 64-bit result now lives in {r4:r3}
    pop     {r4-r6, pc}
```

**Walkthrough:**

1. We're walking two `int16[]` arrays (samples and coefficients), one tap per loop iteration.
2. `LDRSH` sign-extends each int16 into the bottom half of `r5`/`r6`, exactly where `SMLALBB` looks.
3. Each iteration is **one** MAC instruction — the M33 DSP unit folds multiply, sign-extend, and 64-bit add into a single cycle. A 1024-tap filter is ~1024 MACs.
4. Because the accumulator is 64-bit, a 1024-tap Q15 filter at full-scale input can never overflow (`1024 × (2^15 - 1)^2` is still ~40 bits — 24 bits of headroom left). A 32-bit accumulator would have wrapped after roughly 256 worst-case taps.
5. The DIY alternative — `SMULBB` then `ADDS r3,...` then `ADC r4,...` — is three instructions per tap and burns a temp register; `SMLALBB` collapses that into one.

## See also

- [SMLALBT](SMLALBT.md) — 64-bit halfword MAC (BT)
- [SMLALTB](SMLALTB.md) — 64-bit halfword MAC (TB)
- [SMLALTT](SMLALTT.md) — 64-bit halfword MAC (TT)
- [SMLABB](SMLABB.md) — 32-bit accumulator equivalent
- [SMULBB](SMULBB.md) — no-accumulator product alone
- [SMLAL](SMLAL.md) — full 32×32 signed multiply-accumulate

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLALBB*.
