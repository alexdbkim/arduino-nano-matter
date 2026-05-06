# SMULBT — Signed 16×16 multiply: bottom half of `Rn` × top half of `Rm` → 32-bit `Rd`.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMULBT <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** is the cross-lane variant of `SMULBB`: bottom of `Rn` × top of `Rm`. With packed Q15 storage (`[T|B]` = top in bits 31:16, bottom in bits 15:0), this picks the "low sample × high coefficient" combo — exactly what you need for stereo cross-channel mixing or any FIR where one operand is a packed sample-pair and the other has its coefficient already pre-loaded into the top half. Without `SMULBT` you'd `LSR #16` (or `ASR`) to align the half-word, sign-extend, then full `SMULL` — three to four instructions instead of one. The packed Q15 sample storage is the killer use.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | R0–R12, LR; not PC/SP |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |

## Operation (pseudocode)

```text
Rd = SInt(Rn[15:0]) * SInt(Rm[31:16])    // 16×16 → 32 signed
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

This instruction never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMULBT` Rd, Rn, Rm |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

## Example

### Example 1 — low(Rn) × high(Rm) signed product

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMULBT demo: low(Rn) * high(Rm)
    ldr     r1, =0x00007FFF     @ Rn low = 0x7FFF
    ldr     r2, =0x7FFF0000     @ Rm high = 0x7FFF
    smulbt  r0, r1, r2          @ r0 = 0x3FFF0001
loop:
    b   loop
```

**Walkthrough:**

1. `r1`'s low half holds one int16, `r2`'s high half holds another.
2. `smulbt` returns their signed product. Common when one operand is a coefficient packed into the top half of a register.

### Example 2 — Stereo cross-channel mix (left sample × right gain)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Layout: samples = [right | left]   (T = right, B = left)
    @         gains   = [r_gain | l_gain] (T = r_gain, B = l_gain)
    @ Apply the right-channel gain to the left sample (cross feed).
    ldr     r1, =0x55554000     @ samples: right=0x5555, left=0x4000
    ldr     r2, =0x40000000     @ gains  : r_gain=0x4000, l_gain=0x0000
    smulbt  r0, r1, r2          @ r0 = (int16)0x4000 * (int16)0x4000 = 0x10000000
loop:
    b   loop
```

**Walkthrough:**

1. `B` selects bits 15:0 of `r1` (the left sample); `T` selects bits 31:16 of `r2` (the right gain).
2. One instruction, no shifts — the same two loaded words can also feed `SMULBB` (left×left), `SMULTB` (right×left-gain), and `SMULTT` (right×right-gain) for a complete 2×2 stereo mix matrix.

## See also

- [SMULBB](SMULBB.md) — halfword MUL variant (BB)
- [SMULTB](SMULTB.md) — halfword MUL variant (TB)
- [SMULTT](SMULTT.md) — halfword MUL variant (TT)
- [SMULWB](SMULWB.md) — halfword MUL variant (WB)
- [SMULWT](SMULWT.md) — halfword MUL variant (WT)
- [SMLABT](SMLABT.md) — same product, plus accumulator
- [MUL](MUL.md) — plain 32×32 → low 32 multiply

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMULBT*.
