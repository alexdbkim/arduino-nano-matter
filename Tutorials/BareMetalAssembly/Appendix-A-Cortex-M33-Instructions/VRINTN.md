# VRINTN — round float to integral float value, ties to **even** (banker's rounding)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP (FPv5-SP)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None (FPU must be enabled)
- **Secure-state required:** No

## Synopsis

```text
VRINTN.F32   <Sd>, <Sm>
```

Unconditional. IEEE-754 default rounding, result kept as F32.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination single-prec FPU reg | S0–S31; result is F32 |
| `<Sm>` | source single-prec FPU reg | S0–S31; F32 input |

## Operation (pseudocode)

```text
Sd = RoundToIntegralFloat(Sm, RoundToNearestEven)
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
| T1 | 32-bit | float→float, round-to-Nearest, ties-Even |

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
    @ VRINTN demo: ties resolve to the even neighbour
    vmov.f32   s0, #2.5
    vrintn.f32 s1, s0          @ s1 = 2.0f
    vmov.f32   s2, #3.5
    vrintn.f32 s3, s2          @ s3 = 4.0f
    vmov.f32   s4, #-0.5
    vrintn.f32 s5, s4          @ s5 = -0.0f  (sign of zero preserved)
loop:
    b   loop
```

**Walkthrough:**

1. `vrintn.f32 s1,s0` — 2.5 → 2.0 (2 is even).
2. `vrintn.f32 s3,s2` — 3.5 → 4.0 (4 is even).
3. `vrintn.f32 s5,s4` — −0.5 → −0.0 (0 is even; the negative sign is kept, IEEE-754 quirk).

This is the part that bites people: `VRINTN` follows `roundeven`, **not** the
schoolbook "0.5 always rounds up" rule. If you actually want schoolbook rounding,
use [VRINTA](VRINTA.md).

## See also

- [VCVTN](VCVTN.md) — same rounding, but produces an integer
- [VRINTA](VRINTA.md) — ties away from zero
- [VRINTP](VRINTP.md) / [VRINTM](VRINTM.md) — toward +∞ / −∞
- [VRINTZ](VRINTZ.md) — toward zero
- [VRINTR](VRINTR.md) / [VRINTX](VRINTX.md) — current FPSCR mode

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VRINTA, VRINTN, VRINTP, VRINTM*.
