# VMAXNM — IEEE-754-2008 floating-point maximum (single precision)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only — `.F64` form unavailable. **There is no plain `VMAX` on Cortex-M33 scalar VFP** — only the IEEE-754-2008 *number*-max, `VMAXNM`.

## Synopsis

```text
VMAXNM.F32 <Sd>, <Sn>, <Sm>    @ Sd = maxNum(Sn, Sm)
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination | S0–S31 |
| `<Sn>` | first operand | S0–S31 |
| `<Sm>` | second operand | S0–S31 |

## Operation (pseudocode)

```text
CheckVFPEnabled();
if   IsQNaN(Sn) && !IsNaN(Sm) then Sd = Sm
elif IsQNaN(Sm) && !IsNaN(Sn) then Sd = Sn
elif IsSNaN(Sn) || IsSNaN(Sm) then Sd = qNaN; FPSCR.IOC = 1
elif both NaN                 then Sd = qNaN
else Sd = (Sn > Sm) ? Sn : Sm
// +0 is treated as larger than -0.
```

A quiet NaN on one operand is treated as "missing" — you get the other value. This is what makes it safe for sensor-fusion clamps where one input may be NaN.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR untouched. Signalling-NaN input sets `FPSCR.IOC`.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VMAXNM.F32 Sd, Sn, Sm` |

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
    @ VMAXNM demo: ReLU(x) = max(x, 0.0)
    @ S0 = x; we need 0.0 in another register.
    @ NOTE: 0.0 is *not* an encodable VFP immediate, so we synthesise it
    @ by subtracting a register from itself (cheap, no literal pool).
    vsub.f32   s1, s1, s1    @ S1 = 0.0
    vmaxnm.f32 s2, s0, s1    @ S2 = ReLU(x)
loop:
    b   loop
```

**Walkthrough:**

1. `vsub.f32 s1, s1, s1` — produces exactly `+0.0` regardless of S1's prior value (well-defined for any finite/normal input; if S1 were NaN this would still give NaN, so initialise sensibly upstream). The literal `#0.0` is **not** an encodable VFP immediate, so this trick or a `vldr` from a literal pool is the standard workaround.
2. `vmaxnm.f32 s2, s0, s1` — branch-free ReLU. NaN input yields `+0.0` — handy if upstream filtering may produce NaNs.

## See also

- [VMINNM](VMINNM.md) — companion min, same NaN rules
- [VSEL](VSEL.md) — branch-free select using APSR flags
- [VMOV](VMOV.md) — load encodable FP immediate

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VMAXNM*.
