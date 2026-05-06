# QDADD — saturating "double then add" (Rd = sat(Rm + sat(2·Rn)))

## Class & availability

- **Class:** Saturation (DSP arithmetic)
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
QDADD{<c>}{<q>} {<Rd>,} <Rm>, <Rn>
```

Computes `Rd = sat32( Rm + sat32(2·Rn) )` — *two* saturations: the doubling clips first (so `Rn = INT32_MIN` cannot silently wrap), and the final add clips again. Designed for Q15 multiply-accumulate where the multiplier produces a Q31 result that has to be doubled before being summed with a Q31 accumulator.

**When you'd actually use this**: in classic Q15→Q31 multiply-accumulate. A 16×16 signed multiply (`SMULBB`) gives a Q30 result, and DSP textbooks insist you double it before merging into a Q31 accumulator (so the sign bit lines up across the format change). `QDADD` does both stages — the doubling and the accumulate — with saturation on each, so neither a pathological coefficient×sample nor a near-full accumulator can wrap. Replacing the naive `LSL #1; ADD` with one `QDADD` is the difference between a filter that quietly inverts on a transient and one that simply clips and tells you. The sticky `Q` bit (read with `MRS r?, APSR`, cleared with `MSR APSR_nzcvq`) is your "filter is being driven outside its stable range" alarm — there is no `Bxx` branch that tests it.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR. If omitted, `Rd = Rm`. |
| `<Rm>` | accumulator (added to) | R0–R12, LR |
| `<Rn>` | value to be doubled | R0–R12, LR |

## Operation (pseudocode)

```text
if ConditionPassed() then
    (doubled, sat1) = SignedSatQ(2 * SInt(R[n]), 32)
    (result,  sat2) = SignedSatQ(SInt(R[m]) + SInt(doubled), 32)
    R[d] = result<31:0>
    if sat1 || sat2 then APSR.Q = '1'
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | ✓ |

`Q` latches if *either* the doubling or the final add saturated. **Q is sticky**; only `MSR APSR_nzcvq, Rn` (bit 27 = 0) clears it. You can't tell which step clipped — it's a "did anything bad happen" flag.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `QDADD <Rd>, <Rm>, <Rn>` |

DSP-extension; 32-bit Thumb only.

## Exceptions / faults

- (none).

## Example

### Example 1 — Q15→Q31 MAC and double-stage saturation

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Q15 MAC: acc += 2 * (a * b), all Q31 fixed-point.
    @ r4 = Q31 accumulator, r5 = sample a (Q15), r6 = coeff b (Q15).
    mov     r4, #0
    ldr     r5, =0x6000         @ a ≈ 0.75 in Q15
    ldr     r6, =0x4000         @ b = 0.5  in Q15
    smulbb  r0, r5, r6          @ r0 = a*b in Q30 (lower 16x16 → 32)
    qdadd   r4, r4, r0          @ r4 = sat(r4 + sat(2*r0)) → Q31 accumulator

    @ Worst-case: doubling overflows by itself.
    ldr     r7, =0x40000001     @ 2 * r7 wraps without saturation
    mov     r4, #0
    qdadd   r4, r4, r7          @ doubled stage clips to +INT32_MAX, Q=1
loop:
    b   loop
```

**Walkthrough:**

1. `smulbb r0, r5, r6` — multiply two Q15 halves into a Q30 32-bit result. (Plain `SMULBB`, no saturation yet.)
2. `qdadd r4, r4, r0` — the canonical Q15→Q31 MAC step: doubling promotes Q30 to Q31, then the add merges into the Q31 accumulator. Using `QDADD` instead of "shift left 1 then add" is the safe form: `LSL #1` of `0x40000001` would silently wrap to a huge negative; `QDADD` clamps it to `+INT32_MAX` and tells you about it via `Q`.
3. Second `qdadd` — demonstrates the doubling-stage saturation. Even though the final add (`0 + clipped`) fits trivially, `Q` is already latched from the inner saturation. This is the part that bites people: the operand you need to *not* be `INT32_MIN/2 ± something extreme` is `Rn`, not `Rm`.

### Example 2 — two-tap FIR accumulator

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Two-tap FIR: acc = 2*a0*x0 then acc += 2*a1*x1, all Q15 inputs → Q31 acc.
    mov     r4, #0              @ Q31 accumulator starts at 0
    ldr     r5, =0x5A82         @ a0 ≈ 0.7071 in Q15
    ldr     r6, =0x5A82         @ x0 ≈ 0.7071 in Q15
    smulbb  r0, r5, r6          @ r0 = a0*x0 in Q30 (≈ 0.5)
    qdadd   r4, r4, r0          @ acc = sat(0 + sat(2*r0)) ≈ +1.0 in Q31, no clip

    ldr     r5, =0x4000         @ a1 = 0.5 in Q15
    ldr     r6, =0x7FFF         @ x1 ≈ 0.99997 in Q15
    smulbb  r0, r5, r6          @ r0 = a1*x1 in Q30 (≈ 0.5)
    qdadd   r4, r4, r0          @ acc + ~1.0 → already at ~1.0 → clips, Q=1

    @ Inspect Q via APSR; there is no Bxx for it.
    mrs     r7, apsr
    bic     r7, r7, #(1 << 27)
    msr     APSR_nzcvq, r7
loop:
    b   loop
```

**Walkthrough:**

1. `smulbb r0, r5, r6` — multiplies the bottom halves of `r5` and `r6` as signed 16-bit values, producing a 32-bit Q30 result. No saturation here; the Q30 product always fits.
2. First `qdadd` — doubles the Q30 product up to Q31 (still fits because `0.5 × 2 = 1.0` clamps cleanly to `+INT32_MAX`'s neighbour) and adds to `r4` which is zero. Net effect: `r4` ≈ +1.0 in Q31.
3. Second `qdadd` — accumulator is already near Q31's ceiling and we're adding another ≈+1.0 product; the *outer* add saturates this time. `Q` latches; the previous good result was preserved at `+INT32_MAX`. A naive `lsl r0, r0, #1; add r4, r4, r0` would wrap to a large negative number — exactly the silent failure mode `QDADD` exists to prevent.
4. The `MRS`/`BIC #(1<<27)`/`MSR APSR_nzcvq` ritual is the only way to clear sticky `Q`. There is no `Bxx Q`-condition.

## See also

- [QDSUB](QDSUB.md) — saturating `Rm − sat(2·Rn)` (the matching subtract form)
- [QADD](QADD.md) — plain saturating add (no doubling)
- [SMLABB](SMLABB.md) / [SMULBB](SMULBB.md) — the 16×16 multiplies typically feeding `QDADD`
- [SSAT](SSAT.md) — explicit clip to a chosen bit width

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.x — *QDADD*.
