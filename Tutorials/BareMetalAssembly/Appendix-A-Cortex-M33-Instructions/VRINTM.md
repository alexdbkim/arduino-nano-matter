# VRINTM — round float to integral float value, toward −∞ (floor, result stays float)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP (FPv5-SP)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None (FPU must be enabled)
- **Secure-state required:** No

## Synopsis

```text
VRINTM.F32   <Sd>, <Sm>
```

**When you'd actually use this** is when you need the floor of a float as another float — `floorf(x)` in a single instruction with the result still on the FPU side. Same **M = Minus-infinity = floor** mnemonic as [VCVTM](VCVTM.md). The classic use is the always-non-negative fractional part: `frac = x - VRINTM(x)` is in `[0, 1)` even for negative `x` — exactly what phase accumulators, texture interpolation, and table-lookup-with-linear-interpolation want. Without it you'd call libm `floorf` (dozens of cycles) or branch on sign yourself.


Unconditional. The float→float equivalent of `floorf`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination single-prec FPU reg | S0–S31; result is F32 |
| `<Sm>` | source single-prec FPU reg | S0–S31; F32 input |

## Operation (pseudocode)

```text
Sd = RoundToIntegralFloat(Sm, RoundTowardMinusInfinity)
if inexact then FPSCR.IXC = 1
if SNaN(Sm) then FPSCR.IOC = 1
```

Independent of `FPSCR.RMode`.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | float→float, round toward −∞ |

32-bit Thumb-2 only.

## Exceptions / faults

- UsageFault if FPU disabled.
- FPSCR `IOC` on signaling NaN, `IXC` on non-integral input.

## Example


### Example 1 — floor() in one instruction (float result)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VRINTM demo: floor() in one instruction
    ldr        r0, =0x40399999  @ bits of 2.9f
    vmov       s0, r0
    vrintm.f32 s1, s0          @ s1 = 2.0f
    ldr        r0, =0xC0066666  @ bits of -2.1f
    vmov       s2, r0
    vrintm.f32 s3, s2          @ s3 = -3.0f  (floor(-2.1) = -3)
    ldr        r0, =0x80000000  @ bits of -0.0f
    vmov       s4, r0
    vrintm.f32 s5, s4          @ s5 = -0.0f  (sign-of-zero preserved)
loop:
    b   loop
```

**Walkthrough:**

1. `vrintm.f32 s1,s0` — 2.9 floors to 2.0.
2. `vrintm.f32 s3,s2` — −2.1 floors to −3.0 (more negative).
3. `vrintm.f32 s5,s4` — −0.0 stays −0.0; integers (including signed zero) are unchanged and `IXC` is not set.

This is the part that bites people: for negative inputs, `floorf` and "truncate"
disagree by one. Use [VRINTZ](VRINTZ.md) if you want truncation.

### Example 2 — always-non-negative fractional part: frac = x - floor(x)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  frac_pos
    .thumb_func
frac_pos:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ s0 = input float; return frac in [0, 1) regardless of sign
    vrintm.f32 s1, s0             @ s1 = floor(s0)
    vsub.f32   s0, s0, s1         @ s0 = s0 - floor(s0) = frac in [0,1)
    bx         lr
```

**Walkthrough:**

1. `vrintm.f32 s1,s0` produces the floor as a float — for `s0 = -0.25`, `s1 = -1.0`.
2. `vsub.f32 s0,s0,s1` yields `-0.25 - (-1.0) = 0.75`, the always-non-negative fractional part.
3. Phase accumulators in NCOs, table-lookup-with-interpolation, and texture wrap-around all want this version; the [VRINTZ](VRINTZ.md) version gives a *signed* fract instead.

## See also

- [VCVTM](VCVTM.md) — same rounding, integer result
- [VRINTP](VRINTP.md) — toward +∞ (ceil)
- [VRINTA](VRINTA.md) / [VRINTN](VRINTN.md) — round-to-nearest variants
- [VRINTZ](VRINTZ.md) — toward zero (truncation)
- [VRINTR](VRINTR.md) / [VRINTX](VRINTX.md) — current FPSCR mode

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VRINTA, VRINTN, VRINTP, VRINTM*.
