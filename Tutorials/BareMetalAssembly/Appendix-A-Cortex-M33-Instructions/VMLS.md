# VMLS — floating-point multiply-subtract (single precision, two roundings)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only — `.F64` form is unavailable. Two IEEE roundings (mul, then sub). For one rounding use [`VFMS`](VFMS.md).

## Synopsis

```text
VMLS.F32 <Sd>, <Sn>, <Sm>      @ Sd = Sd - (Sn * Sm)
```

**When you'd actually use this** is the legacy two-rounding `acc -= prod` — the same niche as `VMLA`'s sibling: reproducing strict-IEEE behaviour from older toolchains, matching a reference C build that disabled FMA contraction, or bit-exact regression tests. For numerical work where the subtraction can cancel — residuals, IIR feedback, error terms in a Kalman update — `VFMS`'s single rounding is materially more accurate at the same cost. Treat `VMLS` as the compatibility instruction; reach for `VFMS` in any *new* floating-point inner loop where the result feeds another subtraction or comparison.

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
Sd   = FPSub(Sd, prod, FPSCR);   // Sd - prod
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR untouched.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VMLS.F32 Sd, Sn, Sm` |

## Exceptions / faults

- UsageFault (`NOCP`) if FPU disabled.

## Example

### Example 1 — single-term regression residual `r = y - x*beta`

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VMLS demo: residual r = y - X*beta  (one term)
    @ S0 = y, S1 = x, S2 = beta
    vmls.f32 s0, s1, s2      @ y -= x*beta   (S0 holds residual)
loop:
    b   loop
```

**Walkthrough:**

1. `vmls.f32 s0, s1, s2` — one fused-looking but **un-fused** subtract. Result is `y - x*beta` with two roundings. If the residual is feeding into another subtract or comparison and you need bit-tight numerics, swap to `VFMS`.

### Example 2 — sensor error `err = expected - gain*raw`

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  sensor_error
    .thumb_func
sensor_error:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ Convert raw ADC sample into an error term against expected value
    @ err = expected - gain * raw   (legacy two-rounding form)
    @ S0 = expected (becomes err)
    @ S1 = gain, S2 = raw
    vmls.f32 s0, s1, s2      @ S0 = expected - gain*raw
    bx       lr
```

**Walkthrough:**

1. `vmls.f32 s0, s1, s2` — typical control-loop helper: turn a raw ADC reading into a residual against the expected value. Two roundings (one for `gain*raw`, one for the subtract) are usually fine for a low-precision PID feedback path. The moment that residual feeds a Kalman gain calculation or a `||err||²` accumulation, swap to `VFMS` so the cancellation bits survive.

## See also

- [VFMS](VFMS.md) — single-rounded counterpart
- [VMLA](VMLA.md) — accumulating sibling
- [VNMLS](VNMLS.md) — negated-accumulator variant

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VMLS (floating-point)*.
