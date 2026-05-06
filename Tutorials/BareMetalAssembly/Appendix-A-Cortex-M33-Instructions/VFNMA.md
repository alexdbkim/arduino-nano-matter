# VFNMA — fused negated multiply-add (single precision, single rounding)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only. Fused, single-rounded counterpart of [`VNMLA`](VNMLA.md).

## Synopsis

```text
VFNMA.F32 <Sd>, <Sn>, <Sm>     @ Sd = -Sd + (-Sn * Sm)  =  -(Sd + Sn*Sm)
```

**When you'd actually use this** shows up most clearly in optimisation/learning steps and certain rotation kernels. A gradient-descent update `param -= lr*grad` is *exactly* `param = -((-param) + lr*grad)`, so pre-negating the parameter lets one fused `VFNMA` do the whole step with a single rounding. It also turns up in QR/Cholesky in-place updates and 2-D rotations where the math naturally produces a "negate the running sum, then add a product" pattern. Single rounding matters here precisely because gradient steps are tiny relative to the parameter — the cancellation regime where the legacy two-round `VNMLA` quietly eats the last few bits of the update.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | accumulator (read+write, negated) | S0–S31 |
| `<Sn>` | multiplicand (negated) | S0–S31 |
| `<Sm>` | multiplier | S0–S31 |

## Operation (pseudocode)

```text
CheckVFPEnabled();
Sd = FPMulAdd(FPNeg(Sd), FPNeg(Sn), Sm, FPSCR);   // single rounding
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR untouched.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VFNMA.F32 Sd, Sn, Sm` |

## Exceptions / faults

- UsageFault (`NOCP`) if FPU disabled.

## Example

### Example 1 — `-(c + a*b)` for Cholesky/LU update kernels

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VFNMA demo: -(c + a*b) in one fused, single-rounded op
    @ S0 = c (acc), S1 = a, S2 = b
    vfnma.f32 s0, s1, s2     @ S0 = -(c + a*b)
loop:
    b   loop
```

**Walkthrough:**

1. `vfnma.f32 s0, s1, s2` — appears in numerical kernels that accumulate negated products (e.g. some Cholesky or LU update steps). One rounding keeps the residual tight.

### Example 2 — gradient-descent step `param -= lr * grad`

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  gd_step
    .thumb_func
gd_step:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ SGD update: param = param - lr * grad
    @ Encoded as VFNMA's  Sd = -((-Sd) + Sn*Sm).
    @ S0 = param, S1 = lr, S2 = grad
    vneg.f32  s0, s0         @ S0 = -param   (seed the negated accumulator)
    vfnma.f32 s0, s1, s2     @ S0 = -((-param) + lr*grad) = param - lr*grad
    bx        lr
```

**Walkthrough:**

1. `vneg.f32 s0, s0` — pre-negate `param` so it can sit in `VFNMA`'s already-negated accumulator slot.
2. `vfnma.f32 s0, s1, s2` — computes `-((-param) + lr*grad)` = `param - lr*grad` in one fused, single-rounded op. When `lr*grad` is many orders of magnitude smaller than `param` (typical late in training), the single rounding is what stops the update from being silently dropped by round-off — a failure mode that is real with the two-round `VNMLA` form.

## See also

- [VNMLA](VNMLA.md) — two-rounding version
- [VFMA](VFMA.md), [VFMS](VFMS.md), [VFNMS](VFNMS.md) — fused family

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VFNMA*.
