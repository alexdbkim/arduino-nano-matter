# SMMLA — Signed 32×32 multiply, add to a 32-bit value placed in the top of a 64-bit field, keep the top 32 bits.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMMLA <Rd>, <Rn>, <Rm>, <Ra>
```

**When you'd actually use this:** SMMLA is **SMMUL plus a free Q31 add** — `Rd = Ra + ((Rn × Rm) >> 32)`, all sign-correct, all in Q31, all in one cycle. That's the inner loop of every Q31 FIR filter: each tap is `acc += coeff[k] * sample[k]`, and `acc`, `coeff`, `sample` are all Q31. Without SMMLA, every tap would need `SMULL r4, r5, Rn, Rm` (writes a 64-bit register pair) followed by an `ADDS/ADC` chain to keep the accumulator in sync — twice the instructions, twice the registers, twice the pressure on a tight FIR kernel. SMMLA collapses all of that to one register and one instruction. It's also the Q31 multiply step inside a biquad direct-form section, the per-sample step of a Q31 LMS adaptive update, and any control-law of the form `y += k·e`.

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
acc64  = (SInt(Ra) << 32) + prod64
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
| T1 | 32-bit | `SMMLA` Rd, Rn, Rm, Ra |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

`Q` is **not** updated by this family — the result is always the top 32 bits of a 64-bit signed product, which can never overflow.

## Example

### Example 1 — single Q31 IIR step `y += b·x`

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMMLA demo: Q31 IIR step y += b * x  (all Q31)
    ldr     r0, =0x10000000     @ running y
    ldr     r1, =0x40000000     @ b
    ldr     r2, =0x20000000     @ x
    smmla   r0, r1, r2, r0      @ r0 = r0 + top32(b*x)
loop:
    b   loop
```

**Walkthrough:**

1. `r0` is the Q31 running accumulator (here, an IIR output).
2. `smmla` adds `top32(r1*r2)` to it. Because all three operands are Q31, the math stays in Q31 throughout — no shifts needed.

### Example 2 — unrolled body of a 4-tap Q31 FIR filter

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ y = h0*x0 + h1*x1 + h2*x2 + h3*x3   (all Q31, accumulator in Q31)
    ldr     r1, =0x20000000     @ h0  (Q31 coefficient)
    ldr     r2, =0x40000000     @ x0  (Q31 sample)
    ldr     r3, =0x10000000     @ h1
    ldr     r4, =0x20000000     @ x1
    ldr     r5, =0x08000000     @ h2
    ldr     r6, =0x10000000     @ x2
    ldr     r7, =0x04000000     @ h3
    ldr     r8, =0x08000000     @ x3

    movs    r0, #0              @ Q31 accumulator y = 0
    smmla   r0, r1, r2, r0      @ y += h0*x0
    smmla   r0, r3, r4, r0      @ y += h1*x1
    smmla   r0, r5, r6, r0      @ y += h2*x2
    smmla   r0, r7, r8, r0      @ y += h3*x3
loop:
    b   loop
```

**Walkthrough:**

1. Each tap is **one** SMMLA. The accumulator `r0` stays Q31 — it never overflows into a 64-bit pair because we discard the lower half of every product as it's computed.
2. Compare to `SMULL` + `ADDS/ADC`: that's 3 instructions per tap and uses an extra scratch register pair. SMMLA is 1 instruction and 0 scratch.
3. In a real driver you'd put the coefficients and samples in arrays and use `LDR Rt, [Rn], #4` post-increment, but the per-tap math is exactly this single SMMLA.
4. If you need the rounded variant for long filters (>~100 taps), swap `smmla` for `smmlar` — same encoding cost.

## See also

- [SMMLAR](SMMLAR.md) — rounding Q31 multiply-accumulate
- [SMMLS](SMMLS.md) — non-rounding Q31 multiply-subtract
- [SMMLSR](SMMLSR.md) — rounding Q31 multiply-subtract
- [SMMUL](SMMUL.md) — non-rounding Q31 multiply
- [SMMULR](SMMULR.md) — rounding Q31 multiply
- [SMULL](SMULL.md) — full 64-bit signed product (no top-32 shortcut)
- [SMLAL](SMLAL.md) — 64-bit signed multiply-accumulate

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMMLA*.
