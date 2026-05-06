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

**When you'd actually use this** is the per-tap inner loop of a Q31-by-Q15 filter — a Q31 sample multiplied by a Q15 coefficient (taken from the bottom half of `Rm`), result implicitly `>>16` to stay in Q31, then accumulated into `Ra`. This is the canonical step for higher-precision audio EQ where samples are kept in Q31 for headroom but coefficients live in Q15 to fit a compact lookup table. Without `SMLAWB` the same step takes `SXTH` + `SMULL` + `LSR #16` + `ADD` — four instructions per tap versus one. Packed Q15 coefficient storage is the killer use: `SMLAWB` picks the bottom Q15 coefficient, `SMLAWT` picks the top, no shifts needed.

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

### Example 1 — Q31 × Q15 → Q31 with accumulate

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

### Example 2 — One pole of a Q31 IIR biquad

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Q31 biquad pole: y_n += a1 * y_{n-1}
    @ y_{n-1} is Q31 (in r1); a1 is Q15 packed in the BOTTOM half of r2
    @ (bits 15:0). SMLAWB does the multiply, the >>16 to stay Q31, and the
    @ accumulate, all in one cycle.
    movs    r0, #0              @ y accumulator (Q31)
    ldr     r1, =0x60000000     @ y_{n-1} = 0.75 in Q31
    movw    r2, #0x6666         @ a1 ≈ 0.8 in Q15 (bottom half)
    smlawb  r0, r1, r2, r0      @ r0 += (y_{n-1} * a1) >> 16
loop:
    b   loop
```

**Walkthrough:**

1. The 48-bit product is `0x60000000 * 0x6666 = 0x0002_6664_0000_0000`; bits [47:16] = `0x4CCC8000`, added to the zero accumulator.
2. To MAC the next coefficient `a2` packed in the **top** half of the same register, swap to `SMLAWT` — one instruction, no reload, no shift.

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
