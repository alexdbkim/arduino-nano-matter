# VFMA — fused multiply-add (single precision, single rounding)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only. Like `VMLA` but with **a single IEEE-754 rounding** at the end — the multiply is computed at infinite precision before the add. This is the modern, IEEE-754-2008 `fma()` primitive, and it's strictly more accurate than `VMLA` for the same inputs.

## Synopsis

```text
VFMA.F32 <Sd>, <Sn>, <Sm>      @ Sd = Sd + (Sn * Sm)   [single rounding]
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
Sd = FPMulAdd(Sd, Sn, Sm, FPSCR);   // exact Sn*Sm, exact add to Sd, then ONE round
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR untouched.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VFMA.F32 Sd, Sn, Sm` |

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
    @ VFMA demo: linear interpolation lerp(a, b, t) = a + (b - a) * t
    @ S0 = a, S1 = b, S2 = t
    vsub.f32 s3, s1, s0      @ S3 = b - a
    vmov.f32 s4, s0          @ S4 = a (accumulator seed)
    vfma.f32 s4, s3, s2      @ S4 = a + (b - a)*t   single rounding
loop:
    b   loop
```

**Walkthrough:**

1. `vsub.f32 s3, s1, s0` — compute `b - a` (one rounding; unavoidable).
2. `vmov.f32 s4, s0` — seed the accumulator with `a`.
3. `vfma.f32 s4, s3, s2` — the magic: `(b-a)*t` is held in extended precision and added to `a` before the single final round. This is the part that bites people writing `a + (b-a)*t` with `VMLA` and getting last-bit drift.

## See also

- [VMLA](VMLA.md) — same shape, two roundings
- [VFMS](VFMS.md), [VFNMA](VFNMA.md), [VFNMS](VFNMS.md) — fused siblings
- [VMOV](VMOV.md) — register copy used to seed accumulator

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VFMA*.
