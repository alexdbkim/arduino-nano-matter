# VRINTZ — round float to integral float value, toward zero (truncation, result stays float)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP (FPv5-SP)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None (FPU must be enabled)
- **Secure-state required:** No

## Synopsis

```text
VRINTZ{<cond>}.F32   <Sd>, <Sm>
```

The `truncf` of the FPU. Unlike the `VCVTA/N/P/M` family, `VRINTZ` (and `VRINTR`,
`VRINTX`) **do** allow an IT-block condition.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination single-prec FPU reg | S0–S31; result is F32 |
| `<Sm>` | source single-prec FPU reg | S0–S31; F32 input |

## Operation (pseudocode)

```text
Sd = RoundToIntegralFloat(Sm, RoundTowardZero)
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
| T1 | 32-bit | float→float, round toward zero |

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
    @ VRINTZ demo: truncf() — drop the fractional part, keep the sign
    ldr        r0, =0x40399999  @ bits of 2.9f
    vmov       s0, r0
    vrintz.f32 s1, s0          @ s1 =  2.0f
    ldr        r0, =0xC0399999  @ bits of -2.9f
    vmov       s2, r0
    vrintz.f32 s3, s2          @ s3 = -2.0f   (toward 0, NOT toward -inf)
    ldr        r0, =0xBF333333  @ bits of -0.7f
    vmov       s4, r0
    vrintz.f32 s5, s4          @ s5 = -0.0f   (sign preserved)
loop:
    b   loop
```

**Walkthrough:**

1. `vrintz.f32 s1,s0` — 2.9 truncates to 2.0.
2. `vrintz.f32 s3,s2` — −2.9 truncates to −2.0 (round toward zero, **not** floor).
3. `vrintz.f32 s5,s4` — −0.7 truncates to −0.0 — note the negative zero.

Pick `VRINTZ` when you want C-style `(int)x` semantics but need a float result.

## See also

- [VCVT](VCVT.md) — float→int with the same round-toward-zero default
- [VRINTM](VRINTM.md) — round toward −∞ (floor — different for negatives)
- [VRINTA](VRINTA.md) / [VRINTN](VRINTN.md) / [VRINTP](VRINTP.md) — other directed rounds
- [VRINTR](VRINTR.md) — round per current FPSCR mode (no inexact exception)
- [VRINTX](VRINTX.md) — round per current FPSCR mode (sets inexact)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VRINTZ (round floating-point to integral value, round toward zero)*.
