# SMMLS — Signed 32×32 multiply, subtract from a 32-bit value placed in the top of a 64-bit field, keep the top 32 bits.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMMLS <Rd>, <Rn>, <Rm>, <Ra>
```

**When you'd actually use this:** SMMLS is the mirror image of SMMLA — `Rd = Ra − ((Rn × Rm) >> 32)`, all Q31, one cycle. The motivating shape is the **IIR feedback path** of a biquad: `y = b0·x0 + b1·x1 + b2·x2 − a1·y1 − a2·y2`. The two `−a·y` terms are exactly what SMMLS computes natively — you don't have to negate a coefficient or burn an extra `SUB` after a multiply. It also shows up in any "predictor − correction" structure: Kalman-style updates, LMS coefficient updates of the form `w -= μ·e·x`, and Newton-Raphson refinement steps. Without SMMLS, every subtraction tap costs `SMULL` + `SUBS`/`SBC` on a 64-bit pair — three instructions and a register pair instead of one register.

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
acc64  = (SInt(Ra) << 32) - prod64
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
| T1 | 32-bit | `SMMLS` Rd, Rn, Rm, Ra |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

`Q` is **not** updated by this family — the result is always the top 32 bits of a 64-bit signed product, which can never overflow.

## Example

### Example 1 — basic Q31 multiply-subtract

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMMLS demo: Q31 multiply-subtract
    ldr     r0, =0x40000000     @ accumulator y
    ldr     r1, =0x20000000
    ldr     r2, =0x20000000
    smmls   r0, r1, r2, r0      @ r0 = r0 - top32(r1*r2)
loop:
    b   loop
```

**Walkthrough:**

1. Subtracts `top32(Rn*Rm)` from `Ra` and stores in `Rd`.
2. Useful for IIR sections of the form `y[n] = x[n] - a*y[n-1]`.

### Example 2 — IIR feedback recurrence `acc -= a1·y[n-1]`

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Suppose the numerator already gave us acc = b0*x[n] + b1*x[n-1] + b2*x[n-2].
    @ Now subtract the two pole terms:  acc -= a1*y[n-1]; acc -= a2*y[n-2].
    ldr     r0, =0x30000000     @ acc so far (Q31, from numerator)
    ldr     r1, =0x70000000     @ a1   (Q31 pole coefficient)
    ldr     r2, =0x10000000     @ y[n-1]
    ldr     r3, =0x20000000     @ a2
    ldr     r4, =0x08000000     @ y[n-2]

    smmls   r0, r1, r2, r0      @ acc -= a1 * y[n-1]
    smmls   r0, r3, r4, r0      @ acc -= a2 * y[n-2]
    @ r0 is now the new y[n] in Q31, ready to shift the delay line.
loop:
    b   loop
```

**Walkthrough:**

1. Two SMMLS instructions implement both feedback poles of a biquad. No coefficient negation, no separate `SUB` step.
2. Combined with three SMMLA's for the numerator, an entire biquad section costs **5 instructions** in the inner loop — a massive speedup over the SMULL/ADDS/SBC pattern.
3. Note we're using the non-rounding form here; for cascades of more than ~3 sections, swap to `SMMLSR` to keep the truncation bias from drifting your output.

## See also

- [SMMLA](SMMLA.md) — non-rounding Q31 multiply-accumulate
- [SMMLAR](SMMLAR.md) — rounding Q31 multiply-accumulate
- [SMMLSR](SMMLSR.md) — rounding Q31 multiply-subtract
- [SMMUL](SMMUL.md) — non-rounding Q31 multiply
- [SMMULR](SMMULR.md) — rounding Q31 multiply
- [SMULL](SMULL.md) — full 64-bit signed product (no top-32 shortcut)
- [SMLAL](SMLAL.md) — 64-bit signed multiply-accumulate

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMMLS*.
