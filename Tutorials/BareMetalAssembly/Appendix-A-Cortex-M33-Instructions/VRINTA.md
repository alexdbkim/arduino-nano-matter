# VRINTA — round float to integral float value, ties **away** from zero

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP (FPv5-SP)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None (FPU must be enabled)
- **Secure-state required:** No

## Synopsis

```text
VRINTA.F32   <Sd>, <Sm>
```

Unconditional. Result is still a float — the value is rounded to an integer,
but the type stays `F32`. Compare with [VCVTA](VCVTA.md), which produces a
32-bit integer.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination single-prec FPU reg | S0–S31; result is F32 |
| `<Sm>` | source single-prec FPU reg | S0–S31; F32 input |

## Operation (pseudocode)

```text
Sd = RoundToIntegralFloat(Sm, RoundToNearestAwayFromZero)
if inexact then FPSCR.IXC = 1
if SNaN(Sm) then FPSCR.IOC = 1
```

Independent of `FPSCR.RMode`. Sign of zero and infinities are preserved.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | float→float, round-to-nearest, ties-Away |

32-bit Thumb-2 only.

## Exceptions / faults

- UsageFault if FPU disabled.
- FPSCR `IOC` only on signaling NaN; `IXC` set when input is non-integral.

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
    @ VRINTA demo: result stays as float, ties go away from zero
    vmov.f32   s0, #2.5
    vrinta.f32 s1, s0          @ s1 = 3.0f
    vmov.f32   s2, #-2.5
    vrinta.f32 s3, s2          @ s3 = -3.0f
    ldr        r0, =0x3FB33333  @ bits of 1.4f
    vmov       s4, r0
    vrinta.f32 s5, s4          @ s5 = 1.0f
loop:
    b   loop
```

**Walkthrough:**

1. `vrinta.f32 s1,s0` — 2.5f → 3.0f, still in an S register, still a float.
2. `vrinta.f32 s3,s2` — −2.5f → −3.0f.
3. `vrinta.f32 s5,s4` — 1.4f → 1.0f (no tie).

Use `VRINTA` when you need the rounded value to keep flowing through more
floating-point math, e.g. computing `roundf(x) * scale`. If the next step
needs an integer, use [VCVTA](VCVTA.md) and skip the round-trip.

## See also

- [VCVTA](VCVTA.md) — same rounding, but produces an integer
- [VRINTN](VRINTN.md) — ties to even
- [VRINTP](VRINTP.md) / [VRINTM](VRINTM.md) — toward +∞ / −∞
- [VRINTZ](VRINTZ.md) — toward zero (truncation)
- [VRINTR](VRINTR.md) / [VRINTX](VRINTX.md) — round per current FPSCR mode

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VRINTA, VRINTN, VRINTP, VRINTM (round floating-point to integral value with directed rounding)*.
