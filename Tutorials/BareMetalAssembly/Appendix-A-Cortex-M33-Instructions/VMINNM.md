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

**When you'd actually use this** is for the lower half of a NaN-safe clamp (`max(lo, min(hi, x))`) or for tracking a running minimum across noisy samples — for example the lowest battery voltage observed in a one-minute window. The IEEE-754-2008 "minNum" rule means a quiet-NaN input is ignored: you get the real value instead of poisoning the rest of your pipeline. There is no plain `VMIN` on M33 scalar VFP, so this is the canonical min. The first-time FPU gotcha never goes away — `CPACR.CP10/CP11` must be `0b11` or `vminnm.f32` UsageFaults like every other V-instruction.

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

### Example 1 — branch-free clamp `clamp(x, lo, hi)`

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

### Example 2 — battery low-watermark across three cell readings

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VMINNM demo 2: track the minimum voltage across three cells, NaN-safe.
    @ S0 = lowest_seen (initialised upstream to +Inf or the first reading)
    @ S1, S2, S3 = three new cell-voltage readings (any may be NaN if a cell ADC failed)
    vminnm.f32 s0, s0, s1    @ lowest = min(lowest, cell1)
    vminnm.f32 s0, s0, s2    @ lowest = min(lowest, cell2)  -- NaN ignored
    vminnm.f32 s0, s0, s3    @ lowest = min(lowest, cell3)
loop:
    b   loop
```

**Walkthrough:**

1. Each `vminnm.f32` is one cycle and pulls the running minimum down only when a cell reading is *actually* lower.
2. A failed cell that returned NaN is silently skipped, so the low-watermark isn't permanently stuck at NaN. Compare with the naive `VCMP`+branch sequence, which would keep poisoning the running minimum on the first NaN.
3. Combined with `VMAXNM` you have a complete branch-free clamp — `vmaxnm` for the lower bound, `vminnm` for the upper, both NaN-quiescent.

## See also

- [VMAXNM](VMAXNM.md) — companion max
- [VSEL](VSEL.md) — branch-free select on flags
- [VABS](VABS.md) — common clamp neighbour

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VMINNM*.
