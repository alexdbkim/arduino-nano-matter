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

## See also

- [VMUL](VMUL.md) — much faster; combine with reciprocal
- [VSQRT](VSQRT.md) — also multi-cycle
- [VMRS](VMRS.md) — read DZC after suspect division

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VDIV*.
