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

## See also

- [VFMS](VFMS.md) — single-rounded counterpart
- [VMLA](VMLA.md) — accumulating sibling
- [VNMLS](VNMLS.md) — negated-accumulator variant

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VMLS (floating-point)*.
