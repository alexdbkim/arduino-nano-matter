# SMLALBT — Signed 16×16 multiply (bottom half of `Rn` × top half of `Rm`); accumulate the 32-bit product into a 64-bit `{RdHi:RdLo}` pair.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLALBT <RdLo>, <RdHi>, <Rn>, <Rm>
```

**When you'd actually use this:** `SMLALBT` is the cross-half sibling — bottom of `Rn` × top of `Rm` — accumulating into a 64-bit pair. The 64-bit accumulator is the hero: it gives effectively unlimited headroom for very long signed 16×16 MAC chains where a 32-bit accumulator would overflow. The B/T mix is what makes packed-data inner loops sing — when samples sit in the low halves and coefficients sit in the high halves of paired words, you can fire four taps per `LDR`/`LDR` pair using `SMLALBB`, `SMLALBT`, `SMLALTB`, `SMLALTT` in sequence with no shifting or unpacking. Typical use: long FIR/biquad chains for room-correction EQ, sensor-fusion integrators that accumulate for hours, and audio energy summers that only square-root at the end. Without it, you'd need a `SXTH` + `ASR #16` + `MUL` + `ADDS` + `ADC` chain — five instructions per tap instead of one, plus a scratch register.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<RdLo>` | low 32 bits of 64-bit accumulator (read+written) | R0–R12, LR; must differ from `<RdHi>` |
| `<RdHi>` | high 32 bits of 64-bit accumulator (read+written) | R0–R12, LR; must differ from `<RdLo>` |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |

## Operation (pseudocode)

```text
prod32 = SInt(Rn[15:0]) * SInt(Rm[31:16])
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
| T1 | 32-bit | `SMLALBT` RdLo, RdHi, Rn, Rm |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

`Q` is **not** updated — a single 16×16 product can't overflow a 64-bit accumulator.

## Example

### Example 1 — single cross-half MAC seed

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMLALBT demo: low(Rn) * high(Rm) into 64-bit accumulator
    movs    r0, #0
    movs    r1, #0
    ldr     r2, =0x00007FFF     @ Rn low
    ldr     r3, =0x7FFF0000     @ Rm high
    smlalbt r0, r1, r2, r3
loop:
    b   loop
```

**Walkthrough:**

1. Pack one int16 in `r2[15:0]` and another in `r3[31:16]`.
2. `smlalbt` multiplies low-of-Rn by high-of-Rm and accumulates into `{RdHi:RdLo}`.

### Example 2 — sample-bottom × coefficient-top FIR step

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  fir_smlalbt
    .thumb_func
fir_smlalbt:
    @ Samples are packed (s0_lo | s1_hi) per word, coeffs are (c0_lo | c1_hi).
    @ This step pairs sample-bottom with coefficient-top.
    @ r0 = sample word ptr, r1 = coeff word ptr, r2 = N pairs
    push    {r4-r6, lr}
    movs    r3, #0              @ acc lo
    movs    r4, #0              @ acc hi
1:  ldr     r5, [r0], #4        @ packed (s0 in low, s1 in high)
    ldr     r6, [r1], #4        @ packed (c0 in low, c1 in high)
    smlalbt r3, r4, r5, r6      @ {r4:r3} += s0 * c1
    subs    r2, r2, #1
    bne     1b
    pop     {r4-r6, pc}
```

**Walkthrough:**

1. The sample stream stores two int16s per 32-bit word, low half first; coefficients are packed the same way.
2. We want `s0 * c1` per iteration — sample's bottom half times coefficient's top half. That's the literal definition of `SMLALBT`: B from `Rn`, T from `Rm`.
3. One `LDR` + one `SMLALBT` per pair — no `SXTH`, no `ASR`, no temp register. The DSP unit picks the right halves natively.
4. Because the accumulator is 64-bit, even thousands of these pairs never overflow. A 32-bit MAC would saturate or wrap after a few hundred worst-case Q15 taps — the entire reason this `SMLAL*` family exists is to let you skip the saturation logic.

## See also

- [SMLALBB](SMLALBB.md) — 64-bit halfword MAC (BB)
- [SMLALTB](SMLALTB.md) — 64-bit halfword MAC (TB)
- [SMLALTT](SMLALTT.md) — 64-bit halfword MAC (TT)
- [SMLABT](SMLABT.md) — 32-bit accumulator equivalent
- [SMULBT](SMULBT.md) — no-accumulator product alone
- [SMLAL](SMLAL.md) — full 32×32 signed multiply-accumulate

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLALBT*.
