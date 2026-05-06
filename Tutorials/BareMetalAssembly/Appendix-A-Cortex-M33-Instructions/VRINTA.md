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

**When you'd actually use this** is when you need the schoolbook-rounded value of a float kept *as a float* so the next FPU instruction can keep flowing. Same **A = Away-from-zero ties** mnemonic as [VCVTA](VCVTA.md), but the result stays in an S register. Typical context: `roundf(x) * scale` in audio gain or graphics math, where converting to int and back would lose precision and cost a wider register round-trip. Without it you'd `VCVTA` then `VCVT.F32.S32` back — double the latency, and a possible saturation if `x` is huge.


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


### Example 1 — result stays float, ties go away from zero

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

### Example 2 — roundf(x) * scale staying in the float pipeline

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  round_then_scale
    .thumb_func
round_then_scale:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ s0 = input float, s1 = scale factor
    vrinta.f32 s2, s0             @ s2 = roundf(s0), still F32
    vmul.f32   s0, s2, s1         @ s0 = roundf(s0) * scale
    bx         lr
```

**Walkthrough:**

1. `vrinta.f32 s2,s0` performs schoolbook rounding but keeps the result as a float in `s2`.
2. `vmul.f32 s0,s2,s1` immediately re-uses it in float math — no detour through an integer register, no risk of saturating very large inputs.
3. If you needed an `int` instead, swap to [VCVTA](VCVTA.md) and skip the float path entirely.

## See also

- [VCVTA](VCVTA.md) — same rounding, but produces an integer
- [VRINTN](VRINTN.md) — ties to even
- [VRINTP](VRINTP.md) / [VRINTM](VRINTM.md) — toward +∞ / −∞
- [VRINTZ](VRINTZ.md) — toward zero (truncation)
- [VRINTR](VRINTR.md) / [VRINTX](VRINTX.md) — round per current FPSCR mode

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VRINTA, VRINTN, VRINTP, VRINTM (round floating-point to integral value with directed rounding)*.
