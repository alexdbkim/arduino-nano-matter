# VCVTA — convert float→integer, round to nearest with ties **away** from zero

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP (FPv5-SP)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None (FPU must be enabled)
- **Secure-state required:** No

## Synopsis

```text
VCVTA.S32.F32   <Sd>, <Sm>
VCVTA.U32.F32   <Sd>, <Sm>
```

**When you'd actually use this** is when you want schoolbook "0.5 always rounds up in magnitude" without touching `FPSCR`. The mnemonic to memorise: **A = Away-from-zero on ties** — 2.5→3, −2.5→−3. Typical contexts are `lroundf`-style integer rounding for human-readable values, sensor counts displayed on a UI, and conservative event-counter buckets where you want the absolute value to round outward. Without `VCVTA` you'd compute `VCVT.S32.F32(x + copysignf(0.5f, x))` — a multi-instruction dance instead of one opcode.


No `<cond>` — explicit-rounding `VCVT` flavours are unconditional.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination single-prec FPU reg | S0–S31; holds the 32-bit integer result |
| `<Sm>` | source single-prec FPU reg | S0–S31; F32 input |

## Operation (pseudocode)

```text
Sd = ConvertF32ToInt(Sm, RoundToNearestAwayFromZero,
                     signed = (op == .S32.F32))
if NaN(Sm) or overflow then FPSCR.IOC = 1, Sd = saturated value
if inexact then FPSCR.IXC = 1
```

Independent of `FPSCR.RMode` — equivalent to C99 `lroundf()` semantics.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | float→signed/unsigned 32-bit integer, RTA (round-to-nearest, ties-Away) |

32-bit Thumb-2 only.

## Exceptions / faults

- UsageFault if FPU disabled.
- FPSCR `IOC` for NaN/out-of-range; `IXC` for inexact (almost always set, since rounding
  to integer typically loses the fractional part).

## Example


### Example 1 — ties go away from zero

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VCVTA demo: ties go AWAY from zero
    vmov.f32      s0, #2.5
    vcvta.s32.f32 s1, s0       @ s1 =  3   (2.5 -> 3, away from 0)
    vmov.f32      s2, #-2.5
    vcvta.s32.f32 s3, s2       @ s3 = -3   (-2.5 -> -3, away from 0)
    ldr           r0, =0x3FB33333  @ bits of 1.4f (not encodable as VFP imm)
    vmov          s4, r0
    vcvta.s32.f32 s5, s4       @ s5 =  1   (closer to 1)
loop:
    b   loop
```

**Walkthrough:**

1. `vcvta.s32.f32 s1,s0` — 2.5 sits exactly between 2 and 3; "away from zero" picks 3.
2. `vcvta.s32.f32 s3,s2` — −2.5 sits between −2 and −3; "away from zero" picks −3 (more negative).
3. `vcvta.s32.f32 s5,s4` — 1.4 (loaded as a raw IEEE-754 bit pattern, since `vmov.f32` only accepts a small set of "VFP immediates") is unambiguously nearer 1; tie-breaker is irrelevant.

Use this when you need the schoolbook rounding rule: "0.5 always rounds up in
magnitude". Compilers sometimes emit `VCVTA` for `lroundf()`.

### Example 2 — lroundf-style sensor count for a UI display

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  sample_to_count
    .thumb_func
sample_to_count:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ s0 = filtered sensor sample in float "counts"
    vcvta.s32.f32 s1, s0          @ s1 = lroundf(s0)  -- ties away from zero
    vmov          r0, s1
    bx            lr
```

**Walkthrough:**

1. The filter delivers a non-integer count (e.g. 124.5) in `s0`.
2. `vcvta.s32.f32 s1,s0` rounds with the schoolbook rule — 124.5 → 125, −0.5 → −1 — exactly what a human reading the UI expects.
3. The integer drops into `r0` for return; no `FPSCR` programming required.

## See also

- [VCVTN](VCVTN.md) — round-to-nearest, ties to **even** (IEEE-754 default)
- [VCVTP](VCVTP.md) — round toward +∞ (`ceilf`-style)
- [VCVTM](VCVTM.md) — round toward −∞ (`floorf`-style)
- [VCVT](VCVT.md) — default round-toward-zero (truncation)
- [VRINTA](VRINTA.md) — same rounding mode but result stays as a float

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VCVTA, VCVTN, VCVTP, VCVTM (floating-point to integer with directed rounding)*.
