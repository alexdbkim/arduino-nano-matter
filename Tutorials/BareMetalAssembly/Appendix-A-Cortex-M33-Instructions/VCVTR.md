# VCVTR — convert float→integer using the current FPSCR rounding mode

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP (FPv5-SP)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None (FPU must be enabled)
- **Secure-state required:** No

## Synopsis

```text
VCVTR{<cond>}.S32.F32   <Sd>, <Sm>
VCVTR{<cond>}.U32.F32   <Sd>, <Sm>
```

Identical to `VCVT.S32.F32` / `VCVT.U32.F32` **except** that the rounding mode comes
from `FPSCR.RMode` instead of being forced to round-toward-zero.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination single-prec FPU reg | S0–S31, holds the integer result as a 32-bit bit pattern |
| `<Sm>` | source single-prec FPU reg | S0–S31, F32 input |

## Operation (pseudocode)

```text
mode = FPSCR.RMode      // 00=RN, 01=RP, 10=RM, 11=RZ
Sd   = ConvertF32ToInt(Sm, mode, signed = (op == .S32.F32))
if NaN(Sm) or out_of_range then FPSCR.IOC = 1, Sd = saturated value
if inexact then FPSCR.IXC = 1
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Updates FPSCR cumulative exception bits only.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | float→signed/unsigned 32-bit integer, RMode = FPSCR |

32-bit Thumb-2 only.

## Exceptions / faults

- UsageFault if FPU disabled in CPACR.
- FPSCR `IOC` for NaN / out-of-range, `IXC` for inexact.

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
    @ VCVTR demo: rounding controlled by FPSCR.RMode
    vmov.f32     s0, #2.5           @ s0 = 2.5f
    vcvt.s32.f32  s1, s0            @ RTZ:        s1 = 2
    vcvtr.s32.f32 s2, s0            @ FPSCR mode: s2 = 2 (RNE: ties to even)
    vmov.f32     s3, #3.5           @ s3 = 3.5f
    vcvtr.s32.f32 s4, s3            @ RNE:        s4 = 4 (ties to even -> 4)
loop:
    b   loop
```

**Walkthrough:**

1. `vcvt.s32.f32 s1,s0` — plain `VCVT` always truncates: 2.5 → 2.
2. `vcvtr.s32.f32 s2,s0` — uses FPSCR. After reset `RMode = 00` (round-to-nearest-even). 2.5 has two equally-near integers (2 and 3); RNE picks the even one → 2.
3. `vcvtr.s32.f32 s4,s3` — 3.5 ties between 3 and 4; RNE picks 4.

This is the part that bites people: most C compilers emit `VCVT` (truncating) for
`(int)f`, matching C99 semantics. If you want `lrintf`-style "round per FPSCR",
emit `VCVTR` explicitly — or use [VCVTA](VCVTA.md)/[VCVTN](VCVTN.md)/etc. to
hard-code the mode.

## See also

- [VCVT](VCVT.md) — non-`R` form is round-toward-zero for float→int
- [VCVTA](VCVTA.md) — round to nearest, ties away from zero
- [VCVTN](VCVTN.md) — round to nearest, ties to even
- [VCVTP](VCVTP.md) — round toward +∞
- [VCVTM](VCVTM.md) — round toward −∞

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VCVT, VCVTR (between floating-point and integer)*.
