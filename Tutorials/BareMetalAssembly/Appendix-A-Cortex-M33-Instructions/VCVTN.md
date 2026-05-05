# VCVTN — convert float→integer, round to nearest with ties to **even** (banker's rounding)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP (FPv5-SP)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None (FPU must be enabled)
- **Secure-state required:** No

## Synopsis

```text
VCVTN.S32.F32   <Sd>, <Sm>
VCVTN.U32.F32   <Sd>, <Sm>
```

Unconditional. This is IEEE-754 "roundTiesToEven" — the FPU reset default.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination single-prec FPU reg | S0–S31; holds 32-bit integer result |
| `<Sm>` | source single-prec FPU reg | S0–S31; F32 input |

## Operation (pseudocode)

```text
Sd = ConvertF32ToInt(Sm, RoundToNearestEven,
                     signed = (op == .S32.F32))
if NaN(Sm) or overflow then FPSCR.IOC = 1, Sd = saturated
if inexact then FPSCR.IXC = 1
```

Independent of `FPSCR.RMode`.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | float→signed/unsigned 32-bit integer, RNE (round-to-Nearest-even) |

32-bit Thumb-2 only.

## Exceptions / faults

- UsageFault if FPU disabled.
- FPSCR `IOC` (NaN / out-of-range), `IXC` (inexact).

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
    @ VCVTN demo: ties go to the EVEN neighbour
    vmov.f32      s0, #2.5
    vcvtn.s32.f32 s1, s0       @ s1 = 2 (2 is even, 3 is odd)
    vmov.f32      s2, #3.5
    vcvtn.s32.f32 s3, s2       @ s3 = 4 (4 is even, 3 is odd)
    vmov.f32      s4, #-2.5
    vcvtn.s32.f32 s5, s4       @ s5 = -2
loop:
    b   loop
```

**Walkthrough:**

1. `vcvtn.s32.f32 s1,s0` — 2.5 ties between 2 and 3 → pick 2 (even).
2. `vcvtn.s32.f32 s3,s2` — 3.5 ties between 3 and 4 → pick 4 (even).
3. `vcvtn.s32.f32 s5,s4` — −2.5 ties between −2 and −3 → pick −2 (even).

This is the part that bites people: half the time `VCVTN` rounds 0.5 up, half the
time it rounds it down. That's intentional — RNE eliminates the upward bias of
"always round 0.5 away" and is the IEEE-754 default. Use [VCVTA](VCVTA.md) if you
want `2.5 → 3` and `3.5 → 4`.

## See also

- [VCVTA](VCVTA.md) — ties away from zero
- [VCVTP](VCVTP.md) — round toward +∞
- [VCVTM](VCVTM.md) — round toward −∞
- [VCVT](VCVT.md) — round toward zero (truncation, the default for `(int)f`)
- [VRINTN](VRINTN.md) — same rounding, float→float

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VCVTA, VCVTN, VCVTP, VCVTM (floating-point to integer with directed rounding)*.
