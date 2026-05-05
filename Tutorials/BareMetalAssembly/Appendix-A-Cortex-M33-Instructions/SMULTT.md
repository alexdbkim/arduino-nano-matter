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
