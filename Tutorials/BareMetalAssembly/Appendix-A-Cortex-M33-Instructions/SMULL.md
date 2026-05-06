# SMULL — signed 32×32 → 64-bit multiply

## Class & availability

- **Class:** Multiply (arithmetic)
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMULL{<cond>} <RdLo>, <RdHi>, <Rn>, <Rm>
```

`RdHi:RdLo = SignExtend(Rn) × SignExtend(Rm)` — full 64-bit signed product split across two registers.

**When you'd actually use this**: Reach for SMULL whenever the true product won't fit in 32 bits *and* the operands are signed. The headliner is fixed-point multiply: Q15×Q15→Q30 or Q1.31×Q1.31→Q2.62, then shift right to land back in your target Q-format. It's also the right tool for a signed reciprocal-magic-number divide and for sign-correct overflow checks (if `RdHi` isn't the sign-extension of `RdLo`, a 32-bit MUL would have wrapped). Don't substitute UMULL when an operand can be negative — the high half will be wrong by a multiple of 2³² and the bug only shows on negative inputs.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<RdLo>` | low 32 bits of product | `R0`–`R12` |
| `<RdHi>` | high 32 bits of product | `R0`–`R12`, must differ from `<RdLo>` |
| `<Rn>` | first factor (signed) | `R0`–`R12` |
| `<Rm>` | second factor (signed) | `R0`–`R12` |

**Operand order:** `SMULL RdLo, RdHi, Rn, Rm` — low first, then high. `RdLo == RdHi` is UNPREDICTABLE.

## Operation (pseudocode)

```text
if ConditionPassed() then
    result = SInt(R[n]) * SInt(R[m])    // 64-bit signed product
    R[dHi] = result<63:32>
    R[dLo] = result<31:0>
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never on Armv8-M.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMULL RdLo, RdHi, Rn, Rm` (32-bit only) |

## Exceptions / faults

- (none).

## Example

### Example 1 — signed Q16.16 scale via 64-bit product

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMULL demo: signed 64-bit product, then arithmetic-shift back to Q16.16
    ldr     r0, =-1500          @ a signed value
    ldr     r1, =0x00018000     @ 1.5 in Q16.16
    smull   r2, r3, r0, r1      @ r3:r2 = a * 1.5  (signed, 64-bit)
    lsrs    r2, r2, #16
    orr     r2, r2, r3, lsl #16 @ r2 = (a * 1.5) >> 16 (arith semantics in r3)
    @ if you only need the high half:
    smull   r4, r5, r0, r1
    @ r5 holds the sign-correct high 32 bits, e.g. for a 32-bit overflow check
loop:
    b       loop
```

**Walkthrough:**

1. `smull r2, r3, r0, r1` — `−1500 × 0x00018000 = −98304000`. As a 64-bit signed value the high word is sign-extended (all 1s for a negative result); UMULL would have given a positive 64-bit answer instead.
2. The shift sequence reconstructs the 32-bit Q16.16 result; in production code you'd inspect `r3` separately to detect overflow.

### Example 2 — Q15 × Q15 fixed-point multiply with a wide-shift recombine

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global reset_handler
    .thumb_func
reset_handler:
    ldr     r0, =0x4000         @ 0.5 in Q15
    ldr     r1, =0x6666         @ ~0.8 in Q15
    smull   r2, r3, r0, r1      @ r3:r2 = 0.4 in Q30 (signed)
    lsr     r2, r2, #15
    orr     r2, r2, r3, lsl #17 @ r2 = (r3:r2) >> 15 = 0.4 in Q15
loop:
    b       loop
```

**Walkthrough:**

1. `smull r2, r3, r0, r1` — full signed 64-bit product. With Q15 inputs the result is Q30 in `r3:r2`; using plain `MUL` would have lost the high bit of negative products.
2. To return to Q15 we shift the 64-bit value right by 15. Cortex-M has no native 64-bit shift, so we open-code it as `lsr` of the low half + `orr` of the high half shifted up by 17 (= 32 − 15).
3. For potentially negative products you'd swap the `lsr` for `asr` to keep the sign bit; here both inputs are positive so unsigned shift is fine.

## See also

- [UMULL](UMULL.md) — the unsigned counterpart
- [SMLAL](SMLAL.md) — signed multiply-accumulate into a 64-bit pair
- [MUL](MUL.md) — only the low 32 bits (signed = unsigned at that width)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.180 — *SMULL*.
