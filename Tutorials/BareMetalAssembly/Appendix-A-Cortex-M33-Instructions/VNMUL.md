# VNMUL — floating-point negated multiply (single precision)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only. `.F64` is unavailable on this part.

## Synopsis

```text
VNMUL.F32 <Sd>, <Sn>, <Sm>     @ Sd = -(Sn * Sm)
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination | S0–S31 |
| `<Sn>` | multiplicand | S0–S31 |
| `<Sm>` | multiplier | S0–S31 |

## Operation (pseudocode)

```text
CheckVFPEnabled();
Sd = FPNeg(FPMul(Sn, Sm, FPSCR));
```

The negation is a sign-bit flip on the rounded product — it's exact and free.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR untouched. FPSCR exception bits update from the multiply.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VNMUL.F32 Sd, Sn, Sm` |

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
    @ VNMUL demo: subtract a*b from a running total in one op
    @ S0 = total, S1 = a, S2 = b
    vnmul.f32 s3, s1, s2     @ S3 = -(a*b)
    vadd.f32  s0, s0, s3     @ total += -(a*b)  i.e. total -= a*b
loop:
    b   loop
```

**Walkthrough:**

1. `vnmul.f32 s3, s1, s2` — compute `a*b` and flip the sign in one go. Saves a separate `VNEG` after `VMUL`.
2. `vadd.f32 s0, s0, s3` — fold into accumulator. For one-rounding fused form, see `VFMS` (Sd = Sd − Sn*Sm).

## See also

- [VMUL](VMUL.md) — non-negated form
- [VNEG](VNEG.md) — sign flip on its own
- [VFMS](VFMS.md), [VFNMA](VFNMA.md) — fused negative-multiply-add variants

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VNMUL*.
