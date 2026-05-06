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

**When you'd actually use this** is when you naturally want `prod - acc` (the negation is on the accumulator, not the product) — a Newton-Raphson residual `x*y - 1`, the real part of a complex multiply `a*c - b*d`, or a predictor-corrector ODE step shaped `f(t,y)*h - y_prev`. The two roundings are the legacy tax: the modern fused `VFNMS` does the same shape with a single round and is strictly more accurate when cancellation is the hard part — which it almost always is in these patterns. Knowing `VNMLS` is mainly about pattern-matching it in old codegen and recognising it as one instruction.

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

### Example 1 — generic `(a*b) - c`

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

### Example 2 — complex-multiply real part `a*c - b*d`

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  cmul_real
    .thumb_func
cmul_real:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ Real part of (a + bi)*(c + di) = a*c - b*d
    @ S0 = a, S1 = b, S2 = c, S3 = d
    vmul.f32  s4, s1, s3     @ S4 = b*d
    vnmls.f32 s4, s0, s2     @ S4 = a*c - b*d   (real part, two roundings)
    bx        lr
```

**Walkthrough:**

1. `vmul.f32 s4, s1, s3` — pre-compute `b*d` into the negated-accumulator slot.
2. `vnmls.f32 s4, s0, s2` — finish with `a*c - b*d`. Total: three IEEE roundings across the two instructions. The fused `VFNMS` version drops that to two and — more importantly — keeps the cancellation bits when `a*c ≈ b*d` (which is exactly what happens at the centre of an FFT butterfly when phases align).

## See also

- [VMLS](VMLS.md) — non-negated sibling
- [VNMLA](VNMLA.md) — negate accumulator and product
- [VFNMS](VFNMS.md) — fused single-rounded form

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VNMLS*.
