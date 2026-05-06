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

**When you'd actually use this**: in the IIR/FIR feedback path where you compute `acc − 2·coef·sample` over and over. Same Q-format reasoning as `QDADD` — the doubled product must saturate before joining a Q31 accumulator, otherwise an `LSL #1` of, say, `INT32_MIN/2 − 1` flips sign and the filter diverges instantly. `QDSUB` saturates both the doubling and the subtract, so a runaway state stays clamped at `±INT32_MAX` instead of oscillating wildly. Without it, a single transient at the input rail can poison the next 100 samples of output. The sticky `Q` bit (read with `MRS r?, APSR`, cleared with `MSR APSR_nzcvq`) is your "this filter is being driven outside its stable region" alarm; no `Bxx` condition tests it.

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

### Example 1 — biquad-style step + doubling-stage saturation

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

### Example 2 — biquad feedback with extreme tap

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Feedback step: y = y − 2*a1*y_prev. All values pre-multiplied to Q31.
    ldr     r4, =0x70000000     @ y      ≈ +0.875 in Q31
    ldr     r0, =0x10000000     @ tap    ≈ +0.125 in Q31 (fits when doubled)
    qdsub   r4, r4, r0          @ r4 = sat(0.875 − sat(2*0.125)) = +0.625, no clip

    @ A spike on the input drives the tap to near-rail; doubling clips first.
    ldr     r0, =0x40000001     @ tap ≈ +0.50 + ε; 2*tap overflows int32
    qdsub   r4, r4, r0          @ doubled saturates to +INT32_MAX,
                                @ then 0.625 − INT32_MAX → −INT32_MAX, Q=1

    @ Read sticky Q (no Bxx-on-Q in Thumb).
    mrs     r5, apsr
    bic     r5, r5, #(1 << 27)
    msr     APSR_nzcvq, r5
loop:
    b   loop
```

**Walkthrough:**

1. First `qdsub` — every value fits cleanly: `2 * 0x10000000 = 0x20000000`, then `0x70000000 − 0x20000000 = 0x50000000`. `Q` is unchanged.
2. Second `qdsub` — the inner doubling overflows. Without `QDSUB`, `LSL #1` of `0x40000001` becomes `0x80000002` which interpreted as signed is hugely negative, and the subtract would suddenly *increase* the accumulator instead of decreasing it (sign-flip — filters love this). `QDSUB` instead saturates the doubled value to `+INT32_MAX`, so the subtract drives the accumulator to `−INT32_MAX` and `Q` latches.
3. The `MRS`/`BIC`/`MSR APSR_nzcvq` block is required to clear the sticky `Q`. There is no conditional branch on `Q`.

## See also

- [QDADD](QDADD.md) — the matching "double then add"
- [QSUB](QSUB.md) — plain saturating subtract (no doubling)
- [SMLABB](SMLABB.md) — 16×16 MAC, often feeds `QDSUB`/`QDADD`
- [SSAT](SSAT.md) — clip to an arbitrary bit width

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.x — *QDSUB*.
