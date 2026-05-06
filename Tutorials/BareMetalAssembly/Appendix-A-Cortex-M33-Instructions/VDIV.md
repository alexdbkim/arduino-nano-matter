# VDIV — floating-point divide (single precision)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only. The `.F64` form does **not** exist on EFR32MG24.

## Synopsis

```text
VDIV.F32 <Sd>, <Sn>, <Sm>
```

**When you'd actually use this** is sparingly. `VDIV` on Cortex-M33 is multi-cycle and *not pipelined* — roughly 14 cycles versus 1 for `VMUL`. Reach for it at *boundaries*: converting raw ADC counts into engineering units once per sample, computing `RPM = pulses / dt` from a tachometer, or in startup code where one division produces a constant you'll multiply by thousands of times afterward. Inside a hot inner loop, hoist a reciprocal `1.0/k` once and use `VMUL` for the rest. The same first-encounter gotcha as the rest of the family applies: without enabling `CPACR.CP10/CP11`, the very first `vdiv.f32` becomes a `NOCP` UsageFault.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | quotient | S0–S31 |
| `<Sn>` | dividend | S0–S31 |
| `<Sm>` | divisor (must not be ±0 unless you want ±Inf / NaN per IEEE) | S0–S31 |

## Operation (pseudocode)

```text
CheckVFPEnabled();
Sd = FPDiv(Sn, Sm, FPSCR);
// 0/0 -> qNaN with IOC; x/0 -> ±Inf with DZC.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR untouched. Divide-by-zero sets `FPSCR.DZC`; invalid (0/0) sets `FPSCR.IOC`.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VDIV.F32 Sd, Sn, Sm` |

## Exceptions / faults

- UsageFault (`NOCP`) if FPU disabled.
- VDIV is **multi-cycle** on Cortex-M33 (≈14 cycles, non-pipelined for the divider). Hot loops should hoist or replace with reciprocal-multiply.

## Example

### Example 1 — normalise a value by its scale

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VDIV demo: normalise a value by its scale
    vdiv.f32 s2, s0, s1      @ S2 = S0 / S1
    @ For repeated division by the same S1, prefer:
    @   vmov.f32 s3, #1.0
    @   vdiv.f32 s3, s3, s1   @ reciprocal once
    @   vmul.f32 s2, s0, s3   @ then multiply (cheap)
loop:
    b   loop
```

**Walkthrough:**

1. `vdiv.f32 s2, s0, s1` — IEEE single-precision quotient. Slow — don't put it in tight inner loops if you can hoist.
2. The commented alternative shows the standard "compute reciprocal once, multiply many times" trick — `VMUL` is roughly an order of magnitude faster than `VDIV`.

### Example 2 — convert raw ADC counts to millivolts

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VDIV demo 2: mV = (raw / full_scale_counts) * vref_mV
    @ S0 = raw counts (already converted to float)
    @ S1 = full_scale_counts (e.g. 4095.0 for a 12-bit ADC)
    @ S2 = vref_mV          (e.g. 3300.0 for a 3.3 V reference)
    vdiv.f32 s3, s0, s1      @ S3 = raw / full_scale  (in [0, 1])
    vmul.f32 s3, s3, s2      @ S3 = mV
loop:
    b   loop
```

**Walkthrough:**

1. `vdiv.f32 s3, s0, s1` — one division per ADC sample is fine; if you're processing a buffer of samples against a fixed `full_scale`, hoist `1.0/full_scale` outside the loop and use `VMUL` instead.
2. `vmul.f32 s3, s3, s2` — single-cycle scale to mV. Combining the two as `mV = raw * (vref_mV / full_scale)` lets you fold the constants offline and skip `VDIV` entirely.
3. After a suspicious sample (e.g. a zero divisor from a glitched config), read `FPSCR.DZC` via `VMRS` to detect divide-by-zero without trapping.

## See also

- [VMUL](VMUL.md) — much faster; combine with reciprocal
- [VSQRT](VSQRT.md) — also multi-cycle
- [VMRS](VMRS.md) — read DZC after suspect division

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VDIV*.
