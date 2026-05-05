# QDSUB — saturating "double then subtract" (Rd = sat(Rm − sat(2·Rn)))

## Class & availability

- **Class:** Saturation (DSP arithmetic)
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
QDSUB{<c>}{<q>} {<Rd>,} <Rm>, <Rn>
```

Computes `Rd = sat32( Rm − sat32(2·Rn) )` — doubling saturates first, then the subtract saturates again. The dual to `QDADD`; together they implement the "subtract a doubled Q-format product" step in classical Q15 IIR/FIR pipelines.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR. If omitted, `Rd = Rm`. |
| `<Rm>` | minuend (the accumulator) | R0–R12, LR |
| `<Rn>` | value to be doubled and subtracted | R0–R12, LR |

## Operation (pseudocode)

```text
if ConditionPassed() then
    (doubled, sat1) = SignedSatQ(2 * SInt(R[n]), 32)
    (result,  sat2) = SignedSatQ(SInt(R[m]) - SInt(doubled), 32)
    R[d] = result<31:0>
    if sat1 || sat2 then APSR.Q = '1'
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | ✓ |

`Q` latches if either the doubling or the subtract clipped. **Q is sticky**; only `MSR APSR_nzcvq, Rn` (bit 27 = 0) clears it.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `QDSUB <Rd>, <Rm>, <Rn>` |

DSP-extension; 32-bit Thumb only.

## Exceptions / faults

- (none).

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Biquad-style step: y = x − 2*coef*prev (all Q31, saturating).
    ldr     r4, =0x60000000     @ x        (Q31 ≈ +0.75)
    ldr     r5, =0x10000000     @ product  (Q31 ≈ +0.125)
    qdsub   r6, r4, r5          @ r6 = sat(0.75 − sat(2*0.125))
                                @    = sat(0.75 − 0.25) = +0.5 in Q31

    @ Doubling stage saturation example.
    ldr     r4, =0
    ldr     r5, =0x7FFFFFFF     @ 2 * 0x7FFFFFFF cannot fit in int32
    qdsub   r6, r4, r5          @ doubled → +INT32_MAX,
                                @ then 0 − INT32_MAX = -INT32_MAX, Q=1
loop:
    b   loop
```

**Walkthrough:**

1. First `qdsub` — does the Q31 arithmetic safely. `2·0x10000000 = 0x20000000` (no overflow), then `0x60000000 − 0x20000000 = 0x40000000`. No saturation, `Q` unchanged.
2. Second `qdsub` — `2·0x7FFFFFFF` would be `0xFFFFFFFE` interpreted as signed = `-2`, the classic *signed-doubling-wrap* bug. `QDSUB` clips the doubled value to `+INT32_MAX` *before* the subtract, so the rest of the calculation stays sane and you get a clear "something clipped" signal in `APSR.Q`. Replacing a `LSL #1; SUB` pair with one `QDSUB` is how DSP code stays correct on extreme inputs.

## See also

- [QDADD](QDADD.md) — the matching "double then add"
- [QSUB](QSUB.md) — plain saturating subtract (no doubling)
- [SMLABB](SMLABB.md) — 16×16 MAC, often feeds `QDSUB`/`QDADD`
- [SSAT](SSAT.md) — clip to an arbitrary bit width

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.x — *QDSUB*.
