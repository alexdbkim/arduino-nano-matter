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

**When you'd actually use this** is the top-half companion to `SMLAWB`: Q31 × top-half Q15, implicit `>>16` to keep Q31, accumulate. With two Q15 coefficients (or step-sizes) packed as `[T|B]` per word, `SMLAWB`+`SMLAWT` consume both in two cycles — half the load bandwidth of unpacked Q15. The classic context is an LMS adaptive filter: the weight-update step `w += μ·e·x` keeps 32-bit error and sample but a Q15 step-size, and `SMLAWT` runs the update in one instruction. Without it: `LSR #16` + `SXTH` + `SMULL` + `LSR #16` + `ADD` — five instructions per update.

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

### Example 1 — Q31 × top-half Q15, accumulate

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

### Example 2 — LMS adaptive filter weight update

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ LMS update:  w_new = w + mu * (e*x)
    @   r0 = w     (Q31 weight, also the accumulator)
    @   r1 = e*x   (Q31 error-times-sample term)
    @   r2 = [mu | unused]  (Q15 step-size mu lives in the TOP half = bits 31:16)
    @ SMLAWT does mu × (e*x), implicit >>16 keeps Q31, and adds to w in one cycle.
    ldr     r0, =0x40000000     @ existing weight w (Q31)
    ldr     r1, =0x20000000     @ e*x = 0.25 Q31
    ldr     r2, =0x40000000     @ mu  = 0.5  Q15 in top half
    smlawt  r0, r1, r2, r0      @ w += (e*x * mu) >> 16
loop:
    b   loop
```

**Walkthrough:**

1. The 48-bit product is `0x20000000 * 0x4000 = 0x0000_8000_0000_0000`; bits [47:16] = `0x08000000`, then `r0 = 0x40000000 + 0x08000000 = 0x48000000`.
2. The companion `SMLAWB` reaches a *second* step-size packed into the bottom half of the same word (e.g., separate μ for left/right channels) without any extra load or shift.

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
