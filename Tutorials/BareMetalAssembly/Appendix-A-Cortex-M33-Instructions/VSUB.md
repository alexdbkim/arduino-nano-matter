# VSUB — floating-point subtract (single precision)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only. `.F64` is **not** available on this MCU; emit `.F32`.

## Synopsis

```text
VSUB.F32 <Sd>, <Sn>, <Sm>
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination single-precision register | S0–S31 |
| `<Sn>` | minuend | S0–S31 |
| `<Sm>` | subtrahend | S0–S31 |

## Operation (pseudocode)

```text
CheckVFPEnabled();
Sd = FPSub(Sn, Sm, FPSCR);   // i.e. Sn - Sm with IEEE rounding
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR is untouched. IEEE exception bits accumulate in `FPSCR`.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VSUB.F32 Sd, Sn, Sm` |

## Exceptions / faults

- UsageFault (`NOCP`) if FPU is disabled.
- No memory access.

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
    @ VSUB demo: 1-D distance |x1 - x0|
    vsub.f32 s2, s1, s0      @ S2 = x1 - x0  (signed)
    vabs.f32 s2, s2          @ S2 = |S2|
loop:
    b   loop
```

**Walkthrough:**

1. `vsub.f32 s2, s1, s0` — straightforward subtraction; sign of result encodes which is larger.
2. `vabs.f32 s2, s2` — strip the sign bit so `S2` is the unsigned distance.

## See also

- [VADD](VADD.md) — companion add
- [VABS](VABS.md) — strip sign for distance
- [VFMS](VFMS.md) — fused subtract-and-multiply
- [VMRS](VMRS.md)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VSUB (floating-point)*.
