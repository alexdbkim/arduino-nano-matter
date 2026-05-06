# SMULWT — Signed 32-bit × 16-bit (top half of `Rm`) multiply; result is the top 32 bits of the 48-bit product.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMULWT <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** is the top-half companion to `SMULWB`: Q31 × Q15-from-the-top-half, with the implicit `>>16` keeping the result in Q31. With two Q15 coefficients packed as `[T|B]` per word (top half = bits 31:16, bottom = bits 15:0), `SMULWB` consumes the bottom coefficient and `SMULWT` consumes the top — picking either with a one-character suffix. The killer use is per-channel stereo Q31 gain where one packed word holds `[right_gain | left_gain]`. Without `SMULWT` you'd `LSR #16`, sign-extend, full `SMULL`, then `LSR #16` again — four instructions versus one.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | R0–R12, LR; not PC/SP |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |

## Operation (pseudocode)

```text
prod48 = SInt(Rn) * SInt(Rm[31:16])        // 32×16 → 48-bit signed
Rd = prod48[47:16]                         // top 32 bits = Q31 result
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

This instruction never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMULWT` Rd, Rn, Rm |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

## Example

### Example 1 — Q31 × Q15 (top half), Q31 result

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMULWT demo: Q31 * Q15 (top half of Rm)
    ldr     r1, =0x7FFFFFFF
    ldr     r2, =0x40000000     @ coeff in top half
    smulwt  r0, r1, r2          @ r0 ≈ 0x3FFFFFFF
loop:
    b   loop
```

**Walkthrough:**

1. Same as `SMULWB` but takes the coefficient from `Rm[31:16]`.
2. Pairs neatly with `SMULWB` when you've packed two Q15 coefficients into one register — pick either with the suffix.

### Example 2 — Right-channel gain from a packed stereo gain word

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Volume word packs [right_gain | left_gain] (each Q15) — top in bits 31:16,
    @ bottom in bits 15:0. Apply right_gain to a Q31 right-channel sample.
    ldr     r1, =0x60000000     @ right Q31 sample = 0.75
    ldr     r2, =0x40002000     @ r_gain=0x4000 (top), l_gain=0x2000 (bottom)
    smulwt  r0, r1, r2          @ r0 = (sample * r_gain) >> 16, stays Q31
loop:
    b   loop
```

**Walkthrough:**

1. `T` selects bits 31:16 of `r2` (`r_gain = 0x4000` = 0.5 Q15); the implicit `>>16` keeps the Q31 alignment.
2. Process the left channel by re-running the same instruction as `SMULWB` on the same `r2` — one packed gain word feeds both channels with zero reloads.

## See also

- [SMULBB](SMULBB.md) — halfword MUL variant (BB)
- [SMULBT](SMULBT.md) — halfword MUL variant (BT)
- [SMULTB](SMULTB.md) — halfword MUL variant (TB)
- [SMULTT](SMULTT.md) — halfword MUL variant (TT)
- [SMULWB](SMULWB.md) — halfword MUL variant (WB)
- [SMLAWT](SMLAWT.md) — same product, plus accumulator
- [MUL](MUL.md) — plain 32×32 → low 32 multiply

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMULWT*.
