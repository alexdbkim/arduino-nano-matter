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

## See also

- [VCVTP](VCVTP.md) — same rounding, integer result
- [VRINTM](VRINTM.md) — toward −∞ (floor)
- [VRINTA](VRINTA.md) / [VRINTN](VRINTN.md) — round-to-nearest variants
- [VRINTZ](VRINTZ.md) — toward zero
- [VRINTR](VRINTR.md) / [VRINTX](VRINTX.md) — current FPSCR mode

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VRINTA, VRINTN, VRINTP, VRINTM*.
