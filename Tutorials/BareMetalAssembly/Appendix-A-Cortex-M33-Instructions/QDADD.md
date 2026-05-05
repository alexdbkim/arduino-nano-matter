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

## See also

- [QDSUB](QDSUB.md) — saturating `Rm − sat(2·Rn)` (the matching subtract form)
- [QADD](QADD.md) — plain saturating add (no doubling)
- [SMLABB](SMLABB.md) / [SMULBB](SMULBB.md) — the 16×16 multiplies typically feeding `QDADD`
- [SSAT](SSAT.md) — explicit clip to a chosen bit width

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.x — *QDADD*.
