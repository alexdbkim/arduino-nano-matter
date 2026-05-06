# SMLABT — Signed 16×16 multiply (bottom half of `Rn` × top half of `Rm`), accumulate into `Ra`.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLABT <Rd>, <Rn>, <Rm>, <Ra>
```

**When you'd actually use this** is the cross-lane MAC: bottom of `Rn` × top of `Rm`, accumulated. With packed Q15 storage (`[T|B]` = bits 31:16 over bits 15:0), this is what runs in stereo decorrelators or any FIR where a packed sample-pair meets a coefficient that's already aligned to the top half. Without `SMLABT` you'd `LSR #16`, sign-extend, multiply, add — at least three instructions where `SMLABT` does one. Packed Q15 sample storage plus the `[T|B]` selection trick is the killer use.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | R0–R12, LR; not PC/SP |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |
| `<Ra>` | accumulator GPR | R0–R12, LR |

## Operation (pseudocode)

```text
prod32 = SInt(Rn[15:0]) * SInt(Rm[31:16])
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
| T1 | 32-bit | `SMLABT` Rd, Rn, Rm, Ra |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

## Example

### Example 1 — bottom(Rn) × top(Rm), accumulate

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMLABT demo: bottom of Rn × top of Rm
    movs    r0, #0
    ldr     r1, =0x12345678     @ low half = 0x5678
    ldr     r2, =0xABCD1234     @ top half = 0xABCD
    smlabt  r0, r1, r2, r0      @ r0 += (int16)0x5678 * (int16)0xABCD
loop:
    b   loop
```

**Walkthrough:**

1. Load two 32-bit values whose halves carry independent int16 data.
2. `smlabt` multiplies `Rn[15:0] = 0x5678` with `Rm[31:16] = 0xABCD` (sign-extended to 32-bit), then adds the result to `Ra`.
3. Useful when one operand is laid out `[hi:lo]` and the other is just one packed coefficient.

### Example 2 — Stereo decorrelation MAC (left sample × right coefficient)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Layout: r1 = [right_sample | left_sample]  ([T | B], top=31:16, bottom=15:0)
    @         r2 = [right_coef   | left_coef  ]
    @ Stereo decorrelation feeds a tiny bit of the *other* channel's coefficient
    @ across each sample. Cross-tap = left_sample × right_coef.
    movs    r0, #0
    ldr     r1, =0x00010002     @ right=1, left=2
    ldr     r2, =0x00030004     @ right_coef=3, left_coef=4
    smlabt  r0, r1, r2, r0      @ r0 += left_sample * right_coef = 2*3 = 6
loop:
    b   loop
```

**Walkthrough:**

1. `B` picks bits 15:0 of `r1` (the left sample = 2); `T` picks bits 31:16 of `r2` (the right coefficient = 3).
2. The matching same-channel taps run in parallel: `SMLABB` for left×left, `SMLATT` for right×right, `SMLATB` for the other cross. Same two registers, no reloads.

## See also

- [SMLABB](SMLABB.md) — halfword MAC variant (BB)
- [SMLATB](SMLATB.md) — halfword MAC variant (TB)
- [SMLATT](SMLATT.md) — halfword MAC variant (TT)
- [SMLAWB](SMLAWB.md) — halfword MAC variant (WB)
- [SMLAWT](SMLAWT.md) — halfword MAC variant (WT)
- [SMULBT](SMULBT.md) — same product without accumulator
- [SMLAL](SMLAL.md) — 64-bit signed multiply-accumulate (full 32×32)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLABT*.
