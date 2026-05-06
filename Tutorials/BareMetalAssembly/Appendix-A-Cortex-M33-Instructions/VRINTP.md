# VRINTP — round float to integral float value, toward +∞ (ceiling, result stays float)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP (FPv5-SP)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None (FPU must be enabled)
- **Secure-state required:** No

## Synopsis

```text
VRINTP.F32   <Sd>, <Sm>
```

**When you'd actually use this** is when you need the ceiling of a float as a float — `ceilf(x)` in one instruction with the result still on the FPU side. Same **P = Plus-infinity = ceiling** mnemonic as [VCVTP](VCVTP.md). Typical context: computing the next integer grid line above a floating-point coordinate while staying in the float pipeline, or `VRINTP(x) - x` to get the "distance to next integer" for an interpolation weight. Without it you'd call libm `ceilf` or compute `-VRINTM(-x)` — extra ops for no benefit.


Unconditional. The float-→float equivalent of `ceilf`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination single-prec FPU reg | S0–S31; result is F32 |
| `<Sm>` | source single-prec FPU reg | S0–S31; F32 input |

## Operation (pseudocode)

```text
Sd = RoundToIntegralFloat(Sm, RoundTowardPlusInfinity)
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
| T1 | 32-bit | float→float, round toward +∞ |

32-bit Thumb-2 only.

## Exceptions / faults

- UsageFault if FPU disabled.
- FPSCR `IOC` on signaling NaN, `IXC` on non-integral input.

## Example


### Example 1 — ceil() in one instruction (float result)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VRINTP demo: ceil() in one instruction
    ldr        r0, =0x40066666  @ bits of 2.1f
    vmov       s0, r0
    vrintp.f32 s1, s0          @ s1 = 3.0f
    ldr        r0, =0xC0399999  @ bits of -2.9f
    vmov       s2, r0
    vrintp.f32 s3, s2          @ s3 = -2.0f  (ceil(-2.9) = -2)
    vmov.f32   s4, #4.0
    vrintp.f32 s5, s4          @ s5 = 4.0f   (already integral, IXC not set)
loop:
    b   loop
```

**Walkthrough:**

1. `vrintp.f32 s1,s0` — 2.1 ceilings to 3.0.
2. `vrintp.f32 s3,s2` — −2.9 ceilings to −2.0 (toward +∞).
3. `vrintp.f32 s5,s4` — exact integers pass through unchanged.

### Example 2 — interpolation weight: distance to next integer above x

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  dist_to_ceil
    .thumb_func
dist_to_ceil:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ s0 = input float; return ceilf(s0) - s0
    vrintp.f32 s1, s0             @ s1 = ceilf(s0)
    vsub.f32   s0, s1, s0         @ s0 = ceilf(s0) - s0
    bx         lr
```

**Walkthrough:**

1. `vrintp.f32 s1,s0` produces the ceiling as a float.
2. `vsub.f32 s0,s1,s0` gives `ceilf(s0) - s0` — the gap between `s0` and the next integer above it, useful as an interpolation weight or "time-until-next-tick" computation.
3. Stays entirely in the FPU; no detour through `r`-registers or libm.

## See also

- [VCVTP](VCVTP.md) — same rounding, integer result
- [VRINTM](VRINTM.md) — toward −∞ (floor)
- [VRINTA](VRINTA.md) / [VRINTN](VRINTN.md) — round-to-nearest variants
- [VRINTZ](VRINTZ.md) — toward zero
- [VRINTR](VRINTR.md) / [VRINTX](VRINTX.md) — current FPSCR mode

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VRINTA, VRINTN, VRINTP, VRINTM*.
