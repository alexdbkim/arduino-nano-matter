# VMINNM — IEEE-754-2008 floating-point minimum (single precision)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only — `.F64` form unavailable. **There is no `VMIN` on Cortex-M33 scalar VFP** — only the IEEE-754-2008 *number*-min, `VMINNM`.

## Synopsis

```text
VMINNM.F32 <Sd>, <Sn>, <Sm>    @ Sd = minNum(Sn, Sm)
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
else Sd = (Sn < Sm) ? Sn : Sm
// -0 is treated as smaller than +0.
```

The rule that matters in practice: **a quiet NaN on one side is ignored** — you get the non-NaN value. That's the IEEE-754-2008 "minNum" behaviour and it's why this is the only sensible min for clamps.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR untouched. Signalling-NaN input sets `FPSCR.IOC`.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VMINNM.F32 Sd, Sn, Sm` |

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
    @ VMINNM demo: clamp x into [lo, hi]  ->  min(max(x, lo), hi)
    @ S0 = x, S1 = lo, S2 = hi
    vmaxnm.f32 s3, s0, s1    @ S3 = max(x, lo)
    vminnm.f32 s3, s3, s2    @ S3 = min(S3, hi)   = clamp(x, lo, hi)
loop:
    b   loop
```

**Walkthrough:**

1. `vmaxnm.f32 s3, s0, s1` — lower bound. NaN-safe: a NaN sensor reading paired with a real `lo` yields `lo`, not NaN.
2. `vminnm.f32 s3, s3, s2` — upper bound. Two-instruction branch-free clamp.

## See also

- [VMAXNM](VMAXNM.md) — companion max
- [VSEL](VSEL.md) — branch-free select on flags
- [VABS](VABS.md) — common clamp neighbour

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VMINNM*.
