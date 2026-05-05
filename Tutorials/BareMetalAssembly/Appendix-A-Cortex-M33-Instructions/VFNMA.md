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

## See also

- [VNMLA](VNMLA.md) — two-rounding version
- [VFMA](VFMA.md), [VFMS](VFMS.md), [VFNMS](VFNMS.md) — fused family

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VFNMA*.
