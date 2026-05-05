# SMLAWT — Signed 32-bit × 16-bit (top half of `Rm`) multiply, take the top 32 bits of the 48-bit product, add to `Ra`.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLAWT <Rd>, <Rn>, <Rm>, <Ra>
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
prod48 = SInt(Rn) * SInt(Rm[31:16])        // 32-bit × 16-bit → 48-bit signed
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
| T1 | 32-bit | `SMLAWT` Rd, Rn, Rm, Ra |

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
    @ SMLAWT demo: Q31 × top-half Q15 coefficient
    movs    r0, #0
    ldr     r1, =0x40000000
    ldr     r2, =0x40000000     @ coeff in top half
    smlawt  r0, r1, r2, r0      @ r0 += (r1 * r2[31:16]) >> 16
loop:
    b   loop
```

**Walkthrough:**

1. `smlawt` is identical to `SMLAWB` except the coefficient is taken from the **top** half of `Rm`.
2. Lets you pack two Q15 coefficients into one 32-bit word and pick either with the `B`/`T` suffix.

## See also

- [SMLABB](SMLABB.md) — halfword MAC variant (BB)
- [SMLABT](SMLABT.md) — halfword MAC variant (BT)
- [SMLATB](SMLATB.md) — halfword MAC variant (TB)
- [SMLATT](SMLATT.md) — halfword MAC variant (TT)
- [SMLAWB](SMLAWB.md) — halfword MAC variant (WB)
- [SMULWT](SMULWT.md) — same product without accumulator
- [SMLAL](SMLAL.md) — 64-bit signed multiply-accumulate (full 32×32)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLAWT*.
