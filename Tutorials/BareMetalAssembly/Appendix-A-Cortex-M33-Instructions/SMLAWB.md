# SMLAWB — Signed 32-bit × 16-bit (bottom half of `Rm`) multiply, take the top 32 bits of the 48-bit product, add to `Ra`.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLAWB <Rd>, <Rn>, <Rm>, <Ra>
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | R0–R12, LR; not PC/SP |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |
| `<Ra>` | accumulator GPR | R0–R12, LR |

## Operation (pseudocode)

```text
prod48 = SInt(Rn) * SInt(Rm[15:0])        // 32-bit × 16-bit → 48-bit signed
top32 = prod48[47:16]
result = SInt(Ra) + top32                  // 33-bit signed add
Rd = result[31:0]
if SignedOverflow(Ra, top32) then APSR.Q = 1
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | ✓ |

Sets `Q` on signed overflow of the accumulate or dual-sum step. `N`, `Z`, `C`, `V` are never touched.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMLAWB` Rd, Rn, Rm, Ra |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMLAWB demo: Q31 sample × Q15 coefficient -> Q31 accumulator
    movs    r0, #0
    ldr     r1, =0x40000000     @ sample = 0.5 in Q31
    movw    r2, #0x4000         @ coeff  = 0.5 in Q15 (low half)
    smlawb  r0, r1, r2, r0      @ r0 += (r1 * r2[15:0]) >> 16
loop:
    b   loop
```

**Walkthrough:**

1. `r1` is a full 32-bit (Q31) signal value; `r2[15:0]` is a Q15 coefficient.
2. `smlawb` multiplies them to a 48-bit signed product, takes bits [47:16] (i.e. the Q31 result of a Q31×Q15 multiply), and adds to `r0`.
3. This is the canonical "32-bit state × 16-bit coefficient" step used by every Q31 biquad.

## See also

- [SMLABB](SMLABB.md) — halfword MAC variant (BB)
- [SMLABT](SMLABT.md) — halfword MAC variant (BT)
- [SMLATB](SMLATB.md) — halfword MAC variant (TB)
- [SMLATT](SMLATT.md) — halfword MAC variant (TT)
- [SMLAWT](SMLAWT.md) — halfword MAC variant (WT)
- [SMULWB](SMULWB.md) — same product without accumulator
- [SMLAL](SMLAL.md) — 64-bit signed multiply-accumulate (full 32×32)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLAWB*.
