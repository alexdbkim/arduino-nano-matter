# VMUL — floating-point multiply (single precision)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only — `.F64` form is unavailable on EFR32MG24.

## Synopsis

```text
VMUL.F32 <Sd>, <Sn>, <Sm>
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
Sd = FPMul(Sn, Sm, FPSCR);
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR untouched. Inexact / overflow / underflow bits set in `FPSCR`.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VMUL.F32 Sd, Sn, Sm` |

## Exceptions / faults

- UsageFault (`NOCP`) if FPU disabled.
- IEEE exceptions latched in FPSCR (no trap unless explicitly enabled — Cortex-M33 doesn't trap).

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
    @ VMUL demo: scale a sample by a gain factor
    vmul.f32 s2, s0, s1      @ S2 = sample * gain
    vmul.f32 s2, s2, s1      @ S2 *= gain   (apply twice)
loop:
    b   loop
```

**Walkthrough:**

1. `vmul.f32 s2, s0, s1` — single-precision product with one IEEE rounding.
2. `vmul.f32 s2, s2, s1` — chained multiplies each round independently. If you're multiplying then adding, prefer `VFMA` for one combined rounding.

## See also

- [VDIV](VDIV.md) — companion divide
- [VNMUL](VNMUL.md) — negated product
- [VMLA](VMLA.md), [VFMA](VFMA.md) — multiply-add

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VMUL (floating-point)*.
