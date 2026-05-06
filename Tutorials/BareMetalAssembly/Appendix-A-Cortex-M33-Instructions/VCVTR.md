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

**When you'd actually use this** is when you've explicitly programmed `FPSCR.RMode` (e.g. to round-to-nearest-even for a bias-free numerical algorithm) and want the float→int cast to honour that mode instead of always truncating. Plain `VCVT` ignores `FPSCR` and always rounds toward zero, which matches C-cast semantics but is wrong for `lrintf` or any algorithm where truncation introduces a one-sided bias over millions of samples. Reach for `VCVTR` when you want `FPSCR`-driven rounding and reach for the directed-rounding forms ([VCVTA](VCVTA.md)/[VCVTM](VCVTM.md)/[VCVTN](VCVTN.md)/[VCVTP](VCVTP.md)) when you want the mode hard-wired into the opcode. Without `VCVTR` you'd have to clamp/add 0.5/branch on sign yourself — many cycles per cast instead of one.


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


### Example 1 — FPSCR-mode rounding vs. plain VCVT truncation

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

### Example 2 — round-up mode (RP) via FPSCR for ceiling-style cast

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ Program FPSCR.RMode = 01 (round toward +infinity), then VCVTR honours it.
    vmrs       r0, fpscr
    bic        r0, r0, #(3 << 22)        @ clear RMode field (bits 23:22)
    orr        r0, r0, #(1 << 22)        @ set RMode = 01 (RP)
    vmsr       fpscr, r0
    vmov.f32     s0, #2.25
    vcvtr.s32.f32 s1, s0                  @ RP rounds 2.25 up -> s1 = 3
loop:
    b   loop
```

**Walkthrough:**

1. Read `FPSCR`, clear the two-bit `RMode` field, and write back `01` (round-toward-+∞).
2. `vcvtr.s32.f32 s1,s0` honours the new mode — 2.25 rounds *up* to 3, where plain `VCVT.S32.F32` would give 2.
3. Reset value of `RMode` is `00` (round-to-nearest-even); restore it after this routine if other code assumes the default.

## See also

- [VCVT](VCVT.md) — non-`R` form is round-toward-zero for float→int
- [VCVTA](VCVTA.md) — round to nearest, ties away from zero
- [VCVTN](VCVTN.md) — round to nearest, ties to even
- [VCVTP](VCVTP.md) — round toward +∞
- [VCVTM](VCVTM.md) — round toward −∞

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VCVT, VCVTR (between floating-point and integer)*.
