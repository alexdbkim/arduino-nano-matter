# SMULTT — Signed 16×16 multiply: top half of `Rn` × top half of `Rm` → 32-bit `Rd`.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMULTT <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** is the top-half × top-half companion to `SMULBB`. With two int16 samples packed per word as `[T|B]` (top half = bits 31:16, bottom = 15:0), one `LDR` of `[s1|s0]` and one `LDR` of `[c1|c0]` lets `SMULBB` consume tap 0 and `SMULTT` consume tap 1 — two taps for two loads. Without it, you'd `LSR #16` each operand to align, sign-extend, then a full `SMULL`: 3+ instructions versus one. Tied to packed Q15 storage and stereo right-channel processing.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | R0–R12, LR; not PC/SP |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |

## Operation (pseudocode)

```text
Rd = SInt(Rn[31:16]) * SInt(Rm[31:16])    // 16×16 → 32 signed
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

This instruction never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMULTT` Rd, Rn, Rm |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

## Example

### Example 1 — Top × top signed product

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMULTT demo: both top halves
    ldr     r1, =0x00050000
    ldr     r2, =0x00060000
    smultt  r0, r1, r2          @ r0 = 5*6 = 30
loop:
    b   loop
```

**Walkthrough:**

1. Top halves of both operands taken as int16.
2. `smultt` returns the signed product into a full 32-bit `Rd`.

### Example 2 — Second tap of a packed-Q15 2-tap FIR

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Layout (per word, [T|B] = top 31:16 | bottom 15:0):
    @   r1 = [s1 | s0],  r2 = [c1 | c0].
    @ Tap 0 (s0*c0) was done with SMULBB; tap 1 uses SMULTT.
    ldr     r1, =0x00030002     @ s1=3, s0=2
    ldr     r2, =0x00050004     @ c1=5, c0=4
    smultt  r0, r1, r2          @ r0 = s1*c1 = 3*5 = 15
loop:
    b   loop
```

**Walkthrough:**

1. `T,T` selects bits 31:16 of both registers — `s1=3` and `c1=5`.
2. Combined with `SMULBB` on the same word pair, two MUL instructions cover two FIR taps without any shift, sign-extend, or reload — the bandwidth win that makes packed Q15 worthwhile.

## See also

- [SMULBB](SMULBB.md) — halfword MUL variant (BB)
- [SMULBT](SMULBT.md) — halfword MUL variant (BT)
- [SMULTB](SMULTB.md) — halfword MUL variant (TB)
- [SMULWB](SMULWB.md) — halfword MUL variant (WB)
- [SMULWT](SMULWT.md) — halfword MUL variant (WT)
- [SMLATT](SMLATT.md) — same product, plus accumulator
- [MUL](MUL.md) — plain 32×32 → low 32 multiply

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMULTT*.
