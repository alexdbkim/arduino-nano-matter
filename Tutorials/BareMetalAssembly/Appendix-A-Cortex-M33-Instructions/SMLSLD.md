# SMLSLD — Dual signed 16×16 multiply, then difference the two products and accumulate into a 64-bit register pair.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLSLD <RdLo>, <RdHi>, <Rn>, <Rm>
```

**When you'd actually use this** — long real-part accumulators for complex matched filters where `Σ (a_k·c_k − b_k·d_k)` needs more than 32 bits. Typical of radio-preamble correlation against thousands of complex samples, long-window DCTs, and audio cross-correlation. SMLSLD is SMLSD's 64-bit big sibling; without it you'd hit Q-flag saturation halfway through a real-world correlation window and have to keep rescaling.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<RdLo>` | low 32 bits of 64-bit accumulator (read+written) | R0–R12, LR; must differ from `<RdHi>` |
| `<RdHi>` | high 32 bits of 64-bit accumulator (read+written) | R0–R12, LR; must differ from `<RdLo>` |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |

## Operation (pseudocode)

```text
p1 = SInt(Rn[15:0])  * SInt(Rm[15:0])
p2 = SInt(Rn[31:16]) * SInt(Rm[31:16])
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
| T1 | 32-bit | `SMLSLD` RdLo, RdHi, Rn, Rm |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

`Q` is **not** set by this instruction — a 64-bit accumulator cannot overflow on a single dual-product step.

## Example

### Example 1 — Single complex-Re step into 64-bit accumulator

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMLSLD demo: complex magnitude tracker, real part summed in 64 bits
    movs    r0, #0
    movs    r1, #0
    ldr     r2, =0x00020001     @ a=1, b=2
    ldr     r3, =0x00040003     @ c=3, d=4
    smlsld  r0, r1, r2, r3      @ {r1:r0} += a*c - b*d = -5
loop:
    b   loop
```

**Walkthrough:**

1. Clear the 64-bit accumulator pair.
2. `smlsld` accumulates `Rn[lo]·Rm[lo] - Rn[hi]·Rm[hi]` — the real part of complex multiplication, summed across many samples.

### Example 2 — Long complex correlation: Re-axis 64-bit accumulator

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Σ Re((a_k+b_k i)(c_k+d_k i)) = Σ (a_k c_k - b_k d_k) into {r3:r2}.
    @ A 32-bit SMLSD would saturate after ~64 full-scale taps; the 64-bit
    @ form lets us correlate against a 1000+ symbol preamble safely.
    movs    r2, #0
    movs    r3, #0
    ldr     r0, =0x00020001     @ pair 0: [b0=2 : a0=1]
    ldr     r1, =0x00040003     @ pair 0: [d0=4 : c0=3]
    smlsld  r2, r3, r0, r1      @ {r3:r2} += 1*3 - 2*4 = -5
    ldr     r0, =0x7FFF7FFF     @ pair 1: full-scale samples
    ldr     r1, =0x7FFF7FFF     @ pair 1: full-scale coeffs
    smlsld  r2, r3, r0, r1      @ no risk of 32-bit overflow on the partial sum
loop:
    b   loop
```

**Walkthrough:**

1. `{r3:r2}` is the 64-bit running accumulator (RdLo first).
2. Each SMLSLD folds one complex-multiply real-part into the wide accumulator — two 16×16 multiplies, one subtract, one 64-bit add per cycle.
3. For a real radar / GFSK preamble correlator you'd run hundreds of these in a loop with `LDR […],#4` post-increments and never have to insert a saturating add.

## See also

- [SMLALD](SMLALD.md) — non-exchanged 64-bit dual MAC
- [SMLALDX](SMLALDX.md) — exchanged 64-bit dual MAC
- [SMLSLDX](SMLSLDX.md) — exchanged 64-bit dual multiply-subtract
- [SMLAD](SMLAD.md) — 32-bit accumulator equivalent
- [SMLAL](SMLAL.md) — plain signed 32×32 → 64 multiply-accumulate

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLSLD*.
