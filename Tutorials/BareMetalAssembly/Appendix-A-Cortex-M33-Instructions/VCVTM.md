# VCVTM — convert float→integer, round toward −∞ (floor)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP (FPv5-SP)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None (FPU must be enabled)
- **Secure-state required:** No

## Synopsis

```text
VCVTM.S32.F32   <Sd>, <Sm>
VCVTM.U32.F32   <Sd>, <Sm>
```

Unconditional. Equivalent to `(int)floorf(x)`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination single-prec FPU reg | S0–S31; holds 32-bit integer result |
| `<Sm>` | source single-prec FPU reg | S0–S31; F32 input |

## Operation (pseudocode)

```text
Sd = ConvertF32ToInt(Sm, RoundTowardMinusInfinity,
                     signed = (op == .S32.F32))
if NaN(Sm) or overflow then FPSCR.IOC = 1, Sd = saturated
if inexact then FPSCR.IXC = 1
```

Independent of `FPSCR.RMode`.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | float→signed/unsigned 32-bit integer, round toward −∞ |

32-bit Thumb-2 only.

## Exceptions / faults

- UsageFault if FPU disabled.
- FPSCR `IOC`, `IXC` as for other `VCVT` integer forms.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VCVTM demo: always round DOWN (toward -infinity)
    ldr           r0, =0x40399999  @ bits of 2.9f
    vmov          s0, r0
    vcvtm.s32.f32 s1, s0       @ s1 =  2
    ldr           r0, =0xC0066666  @ bits of -2.1f
    vmov          s2, r0
    vcvtm.s32.f32 s3, s2       @ s3 = -3  (floor(-2.1) = -3)
    vmov.f32      s4, #-5.0
    vcvtm.s32.f32 s5, s4       @ s5 = -5  (already integral)
loop:
    b   loop
```

**Walkthrough:**

1. `vcvtm.s32.f32 s1,s0` — 2.9 floors to 2.
2. `vcvtm.s32.f32 s3,s2` — −2.1 floors to −3 (more negative). This is where
   `floor` differs from "truncate"; truncation would give −2.
3. `vcvtm.s32.f32 s5,s4` — exact integers pass through.

This is the part that bites people: for negative numbers, `(int)x` (i.e. `VCVT`)
and `floorf(x)` (i.e. `VCVTM`) **disagree by one**. Pick the one you actually want.

## See also

- [VCVTP](VCVTP.md) — round toward +∞ (the ceiling)
- [VCVTN](VCVTN.md) — round to nearest, ties to even
- [VCVTA](VCVTA.md) — round to nearest, ties away from zero
- [VCVT](VCVT.md) — round toward zero (truncation)
- [VRINTM](VRINTM.md) — same rounding mode, float→float

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VCVTA, VCVTN, VCVTP, VCVTM (floating-point to integer with directed rounding)*.
