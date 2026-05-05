# VRINTX — round float to integral float using FPSCR mode, **signal inexact**

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP (FPv5-SP)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None (FPU must be enabled)
- **Secure-state required:** No

## Synopsis

```text
VRINTX{<cond>}.F32   <Sd>, <Sm>
```

`VRINTX` is the IEEE-754 `roundToIntegralExact` operation: round per current
mode, and **set `FPSCR.IXC` if the result differs from the input**. Compare
`VRINTR`, which does the same rounding but never sets `IXC`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination single-prec FPU reg | S0–S31; result is F32 |
| `<Sm>` | source single-prec FPU reg | S0–S31; F32 input |

## Operation (pseudocode)

```text
mode = FPSCR.RMode
Sd   = RoundToIntegralFloat(Sm, mode)
if (Sd != Sm)   then FPSCR.IXC = 1     // inexact signaled
if SNaN(Sm)     then FPSCR.IOC = 1
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | float→float, round per FPSCR.RMode, may signal inexact |

32-bit Thumb-2 only.

## Exceptions / faults

- UsageFault if FPU disabled.
- FPSCR `IXC` whenever rounding actually changes the value; `IOC` for SNaN.

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
    @ VRINTX demo: rounds per FPSCR and sets IXC if it had to round
    vmov.f32   s0, #1.25
    vrintx.f32 s1, s0          @ FPSCR default RNE -> s1 = 1.0, FPSCR.IXC := 1
    vmov.f32   s2, #4.0
    vrintx.f32 s3, s2          @ already integral -> s3 = 4.0, IXC not changed
    vmrs       r0, fpscr       @ read FPSCR so software can inspect IXC (bit 4)
loop:
    b   loop
```

**Walkthrough:**

1. `vrintx.f32 s1,s0` — 1.25 isn't integral, so the rounded value (1.0 under
   RNE) differs from the input → `IXC` is sticky-set.
2. `vrintx.f32 s3,s2` — 4.0 is already integral, no rounding occurred, `IXC`
   stays at whatever it was.
3. `vmrs r0, fpscr` — copy FPSCR into r0 so the program can test `IXC` (bit 4).

This is the part that bites people: `VRINTX` is the only `VRINT*` form that
*intentionally* signals inexact. Use it for `nearbyint`-with-FE_INEXACT semantics.
For `nearbyint` semantics that **don't** raise inexact, use [VRINTR](VRINTR.md).

## See also

- [VRINTR](VRINTR.md) — same rounding, never sets `IXC` (`nearbyint`-style)
- [VRINTA](VRINTA.md), [VRINTN](VRINTN.md), [VRINTP](VRINTP.md), [VRINTM](VRINTM.md), [VRINTZ](VRINTZ.md) — fixed rounding modes
- [VMRS](VMRS.md) — read FPSCR to inspect `IXC`

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VRINTX (round floating-point to integral value, signal inexact)*.
