# VNMLS — floating-point negated multiply-subtract (single precision)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only — `.F64` form unavailable. Two roundings; fused single-rounded form is [`VFNMS`](VFNMS.md).

## Synopsis

```text
VNMLS.F32 <Sd>, <Sn>, <Sm>     @ Sd = -Sd + (Sn * Sm)
```

Equivalently: `Sd = (Sn * Sm) - Sd`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | accumulator (read+write) | S0–S31 |
| `<Sn>` | multiplicand | S0–S31 |
| `<Sm>` | multiplier | S0–S31 |

## Operation (pseudocode)

```text
CheckVFPEnabled();
prod = FPMul(Sn, Sm, FPSCR);
Sd   = FPAdd(FPNeg(Sd), prod, FPSCR);   // -Sd + prod
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR untouched.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VNMLS.F32 Sd, Sn, Sm` |

## Exceptions / faults

- UsageFault (`NOCP`) if FPU disabled.

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
    @ VNMLS demo: compute (a*b) - c in one shot
    @ S0 = c (will be overwritten), S1 = a, S2 = b
    vnmls.f32 s0, s1, s2     @ S0 = -c + a*b  =  a*b - c
loop:
    b   loop
```

**Walkthrough:**

1. `vnmls.f32 s0, s1, s2` — common shape inside Newton-Raphson refinements (`x*y - 1`, etc.). Two roundings; for tighter numerics step up to `VFNMS`.

## See also

- [VMLS](VMLS.md) — non-negated sibling
- [VNMLA](VNMLA.md) — negate accumulator and product
- [VFNMS](VFNMS.md) — fused single-rounded form

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VNMLS*.
