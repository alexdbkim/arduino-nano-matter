# SMLABB — Signed 16×16 multiply (bottom half of `Rn` × bottom half of `Rm`), accumulate into `Ra`.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLABB <Rd>, <Rn>, <Rm>, <Ra>
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
prod32 = SInt(Rn[15:0]) * SInt(Rm[15:0])
result = SInt(Ra) + prod32                 // 33-bit signed add
Rd = result[31:0]
if SignedOverflow(Ra, prod32) then APSR.Q = 1
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | ✓ |

Sets `Q` on signed overflow of the accumulate or dual-sum step. `N`, `Z`, `C`, `V` are never touched.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMLABB` Rd, Rn, Rm, Ra |

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
    @ SMLABB demo: biquad coefficient × state, low halves
    @ Pack a Q15 sample in r1[15:0], coefficient in r2[15:0]
    movs    r0, #0
    movw    r1, #0x4000         @ sample = 0.5 in Q15
    movw    r2, #0x2000         @ coeff  = 0.25 in Q15
    smlabb  r0, r1, r2, r0      @ r0 += sample * coeff (no shift)
loop:
    b   loop
```

**Walkthrough:**

1. Zero the accumulator.
2. Place Q15 values in the low halves of `r1` and `r2`. The high halves are ignored by `SMLABB`.
3. `smlabb` does `r0 = r0 + (int16)r1 * (int16)r2`. The product is a Q30 number; for Q15 audio you'd typically follow with a 1-bit left shift or use the `W` variants.

## See also

- [SMLABT](SMLABT.md) — halfword MAC variant (BT)
- [SMLATB](SMLATB.md) — halfword MAC variant (TB)
- [SMLATT](SMLATT.md) — halfword MAC variant (TT)
- [SMLAWB](SMLAWB.md) — halfword MAC variant (WB)
- [SMLAWT](SMLAWT.md) — halfword MAC variant (WT)
- [SMULBB](SMULBB.md) — same product without accumulator
- [SMLAL](SMLAL.md) — 64-bit signed multiply-accumulate (full 32×32)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLABB*.
