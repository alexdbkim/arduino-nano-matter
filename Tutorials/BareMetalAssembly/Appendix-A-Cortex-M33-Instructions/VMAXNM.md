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

**When you'd actually use this** is for **NaN-safe lower-clamping or running-max tracking**. Picture a sensor that occasionally glitches and produces NaN: a plain `VCMP`+branch sequence would propagate the NaN through your output; `VMAXNM` quietly returns the non-NaN operand instead, so a clamp `min(reading, ceiling)` (paired with `VMINNM`) keeps producing sane outputs. There's deliberately no plain `VMAX` on Cortex-M33 scalar VFP — the IEEE-754-2008 *number*-max is the only choice, which is exactly what you want for robust real-time DSP. CPACR first: with the FPU disabled, even `VMAXNM` faults before it can save you from a NaN.

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

### Example 1 — branch-free ReLU `max(x, 0.0)`

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

### Example 2 — running peak-hold across three samples

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VMAXNM demo 2: peak-hold telemetry
    @ S0 = running peak, S1..S3 = three new samples (S2 may legitimately be NaN)
    vmaxnm.f32 s0, s0, s1    @ peak = max(peak, sample1)
    vmaxnm.f32 s0, s0, s2    @ peak = max(peak, sample2)  -- NaN ignored
    vmaxnm.f32 s0, s0, s3    @ peak = max(peak, sample3)
loop:
    b   loop
```

**Walkthrough:**

1. Each `vmaxnm.f32` updates the running peak in one cycle. No branches, no `IT` block — the FPU does the comparison internally.
2. Crucially, when `S2` is a quiet NaN (e.g. a sensor read flagged as invalid), `VMAXNM` returns the *other* operand (`peak`), so the peak is left unchanged instead of being permanently corrupted to NaN.
3. The same pattern with `VCMP`+`vselgt`+`VMRS` would work but is longer and has to be fed `VMRS APSR_nzcv, fpscr` between each comparison — `VMAXNM` collapses all that into one instruction.

## See also

- [VMINNM](VMINNM.md) — companion min, same NaN rules
- [VSEL](VSEL.md) — branch-free select using APSR flags
- [VMOV](VMOV.md) — load encodable FP immediate

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VMAXNM*.
