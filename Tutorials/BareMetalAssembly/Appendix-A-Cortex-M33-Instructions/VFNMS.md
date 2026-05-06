# VFNMS — fused negated multiply-subtract (single precision, single rounding)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only. Fused, single-rounded counterpart of [`VNMLS`](VNMLS.md).

## Synopsis

```text
VFNMS.F32 <Sd>, <Sn>, <Sm>     @ Sd = -Sd + (Sn * Sm)  =  Sn*Sm - Sd
```

**When you'd actually use this** is the textbook Newton-Raphson refinement loop for `1/y` and `1/sqrt(y)`, where the residual is `x*y - 1` (or `x*y*y - 1.5`-style variants) and you need every bit. `VFNMS` computes `Sn*Sm - Sd` in one fused step, so seeding `Sd = 1.0` gives the residual directly and a follow-up `VFMA`/`VFMS` finishes the update. It also turns up in predictor-corrector ODE steps and quadratic-form evaluations of shape `b*x - c`. Single rounding is the whole point: the subtraction in `x*y - 1` is *catastrophic cancellation* near convergence, exactly the case where two-round `VNMLS` destroys the bits the iteration is trying to recover.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | accumulator (read+write, negated) | S0–S31 |
| `<Sn>` | multiplicand | S0–S31 |
| `<Sm>` | multiplier | S0–S31 |

## Operation (pseudocode)

```text
CheckVFPEnabled();
Sd = FPMulAdd(FPNeg(Sd), Sn, Sm, FPSCR);   // single rounding
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR untouched.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VFNMS.F32 Sd, Sn, Sm` |

## Exceptions / faults

- UsageFault (`NOCP`) if FPU disabled.

## Example

### Example 1 — Newton-Raphson residual for `1/y`

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VFNMS demo: Newton step for 1/y -> err = 1 - x*y, then x += x*err
    @ S0 = x (current 1/y estimate), S1 = y, S2 = 1.0 (acc seed)
    vfnms.f32 s2, s1, s0     @ S2 = -1.0 + (y*x)  =  y*x - 1   (residual)
    @ ... use S2 as Newton residual; x_new = x - x*S2 via VFMS
loop:
    b   loop
```

**Walkthrough:**

1. `vfnms.f32 s2, s1, s0` — exact `y*x` minus the seed, single round. This is the textbook "compute residual for Newton-Raphson" idiom and is why fused ops exist on FPv5.

### Example 2 — quadratic micro-step `b*x - c`

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  quad_term
    .thumb_func
quad_term:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ Inner step of a quadratic / Horner-with-subtract: result = b*x - c
    @ S0 = c (will be overwritten with result)
    @ S1 = b, S2 = x
    vfnms.f32 s0, s1, s2     @ S0 = b*x - c   (single rounding)
    bx        lr
```

**Walkthrough:**

1. `vfnms.f32 s0, s1, s2` — folds the multiply and subtract into one instruction with one rounding. Inside a quadratic-formula discriminant or a Horner chain that flips signs, `b*x` and `c` are often nearly equal, so the subtract is the cancellation step. Two-round `VNMLS` quietly loses precision exactly there; `VFNMS` keeps the bits.

## See also

- [VNMLS](VNMLS.md) — two-rounding version
- [VFMA](VFMA.md), [VFMS](VFMS.md), [VFNMA](VFNMA.md) — fused family
- [VSQRT](VSQRT.md), [VDIV](VDIV.md) — common targets for Newton refinement

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VFNMS*.
