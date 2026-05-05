# VRINTR — round float to integral float using FPSCR mode, **no inexact exception**

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP (FPv5-SP)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None (FPU must be enabled)
- **Secure-state required:** No

## Synopsis

```text
VRINTR{<cond>}.F32   <Sd>, <Sm>
```

The IEEE-754 `roundToIntegral` operation that **does not** signal inexact —
i.e. `nearbyint`. Compare [VRINTX](VRINTX.md), which does the same rounding
but sets `FPSCR.IXC`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination single-prec FPU reg | S0–S31; result is F32 |
| `<Sm>` | source single-prec FPU reg | S0–S31; F32 input |

## Operation (pseudocode)

```text
mode = FPSCR.RMode
Sd   = RoundToIntegralFloat(Sm, mode)
// FPSCR.IXC is NOT updated, even if rounding changed the value
if SNaN(Sm) then FPSCR.IOC = 1
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | float→float, round per FPSCR.RMode, no inexact signaling |

32-bit Thumb-2 only.

## Exceptions / faults

- UsageFault if FPU disabled.
- FPSCR `IOC` only on signaling NaN; `IXC` is **never** updated by `VRINTR`.

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
    @ VRINTR demo: nearbyint() — round per FPSCR but don't pollute IXC
    vmrs       r0, fpscr
    bic        r0, r0, #0x10       @ clear IXC (bit 4)
    vmsr       fpscr, r0
    vmov.f32   s0, #1.25
    vrintr.f32 s1, s0              @ s1 = 1.0f, IXC stays clear
    vmov.f32   s2, #-3.5
    vrintr.f32 s3, s2              @ RNE: s3 = -4.0f, IXC still clear
loop:
    b   loop
```

**Walkthrough:**

1. The first three instructions zero `FPSCR.IXC` so we can prove `VRINTR`
   never re-sets it.
2. `vrintr.f32 s1,s0` — 1.25 → 1.0 under RNE, but `IXC` stays clear.
3. `vrintr.f32 s3,s2` — −3.5 → −4.0 (RNE picks the even neighbour), still no `IXC`.

Use `VRINTR` when you want library-quality `nearbyint`/`rintf`-without-FE_INEXACT
semantics, or when you're rounding inside a tight loop and don't want a stray
inexact flag confusing later checks.

## See also

- [VRINTX](VRINTX.md) — same rounding, sets `IXC` on rounding (`rintf` semantics)
- [VRINTA](VRINTA.md), [VRINTN](VRINTN.md), [VRINTP](VRINTP.md), [VRINTM](VRINTM.md), [VRINTZ](VRINTZ.md) — fixed rounding modes
- [VMRS](VMRS.md) / [VMSR](VMSR.md) — read/write FPSCR to control `RMode`

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VRINTR (round floating-point to integral value, do not signal inexact)*.
