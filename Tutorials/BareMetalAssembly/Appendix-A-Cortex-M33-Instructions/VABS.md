# VABS — floating-point absolute value (single precision)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only — `.F64` is unavailable on EFR32MG24. Note: there's also a non-FP integer `QABS`/SIMD form on some cores; this page is the **floating-point** `VABS`.

## Synopsis

```text
VABS.F32 <Sd>, <Sm>            @ Sd = |Sm|  (sign bit cleared)
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination | S0–S31 |
| `<Sm>` | source | S0–S31 |

## Operation (pseudocode)

```text
CheckVFPEnabled();
Sd = Sm with sign bit cleared;   // bitwise: Sd = Sm & 0x7FFFFFFF
// NaN payloads pass through; sign of NaN cleared. No FPSCR exception bits set.
```

It's a sign-bit clear, not a "negate if negative" — so `VABS` of any NaN is still a NaN, just with a positive sign. It does **not** raise Invalid Operation on signalling NaNs.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR untouched. FPSCR untouched.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VABS.F32 Sd, Sm` |

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
    @ VABS demo: |x - y|
    @ S0 = x, S1 = y
    vsub.f32 s2, s0, s1      @ S2 = x - y  (signed)
    vabs.f32 s2, s2          @ S2 = |x - y|
loop:
    b   loop
```

**Walkthrough:**

1. `vsub.f32 s2, s0, s1` — signed difference.
2. `vabs.f32 s2, s2` — single-cycle sign-bit strip. Cheaper than a compare-and-negate.

## See also

- [VNEG](VNEG.md) — sign-bit flip
- [VSUB](VSUB.md), [VSQRT](VSQRT.md) — frequent neighbours in distance/norm code

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VABS (floating-point)*.
