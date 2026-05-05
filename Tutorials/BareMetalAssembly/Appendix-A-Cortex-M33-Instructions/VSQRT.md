# VSQRT — floating-point square root (single precision)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only — `.F64` form is **not** available on EFR32MG24. IEEE-754 correctly rounded square root.

## Synopsis

```text
VSQRT.F32 <Sd>, <Sm>           @ Sd = sqrt(Sm)
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination | S0–S31 |
| `<Sm>` | source | S0–S31 |

## Operation (pseudocode)

```text
CheckVFPEnabled();
Sd = FPSqrt(Sm, FPSCR);
// Sm < 0  -> qNaN, FPSCR.IOC = 1
// Sm = -0 -> -0  (per IEEE)
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR untouched. Negative input sets `FPSCR.IOC` (Invalid Operation).

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VSQRT.F32 Sd, Sm` |

## Exceptions / faults

- UsageFault (`NOCP`) if FPU disabled.
- VSQRT is **multi-cycle, non-pipelined** on Cortex-M33 (~14 cycles). Treat it like `VDIV` — keep it out of innermost loops where possible.

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
    @ VSQRT demo: 2-D Euclidean distance sqrt(dx^2 + dy^2)
    @ S0 = dx, S1 = dy
    vmul.f32  s2, s0, s0     @ dx*dx
    vfma.f32  s2, s1, s1     @ + dy*dy   (fused, single rounding)
    vsqrt.f32 s2, s2         @ sqrt(dx^2 + dy^2)
loop:
    b   loop
```

**Walkthrough:**

1. `vmul.f32 s2, s0, s0` — square `dx`.
2. `vfma.f32 s2, s1, s1` — add `dy*dy` to it with a single rounding (tighter than `VMLA`).
3. `vsqrt.f32 s2, s2` — correctly-rounded square root. Slow — but you usually only need one per distance calc.

## See also

- [VDIV](VDIV.md) — same multi-cycle behaviour
- [VFMA](VFMA.md) — pair with for sum-of-squares
- [VMRS](VMRS.md) — read FPSCR.IOC after suspect inputs

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VSQRT*.
