# VCVT — convert between floating-point, integer, fixed-point, and half-precision

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP (FPv5-SP on Cortex-M33)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅ (single-precision FPU; **no double-precision**)
- **Privilege required:** None (FPU must be enabled in CPACR)
- **Secure-state required:** No

## Synopsis

```text
@ float ↔ integer (default rounds toward zero for float→int)
VCVT{<cond>}.<Tdest>.<Tsrc>   <Sd>, <Sm>

@ float ↔ fixed-point Qn (immediate = number of fraction bits)
VCVT{<cond>}.<Tdest>.<Tsrc>   <Sd>, <Sd>, #<fbits>

@ half ↔ single (top/bottom 16 bits of a 32-bit S register)
VCVTB{<cond>}.F32.F16   <Sd>, <Sm>      @ low half of Sm  -> Sd  (F32)
VCVTT{<cond>}.F32.F16   <Sd>, <Sm>      @ high half of Sm -> Sd  (F32)
VCVTB{<cond>}.F16.F32   <Sd>, <Sm>      @ Sm (F32) -> low half of Sd
VCVTT{<cond>}.F16.F32   <Sd>, <Sm>      @ Sm (F32) -> high half of Sd
```

**When you'd actually use this** is at every boundary between the float pipeline and the integer world. The two workhorse forms are `VCVT.S32.F32` (float → signed int, **C-cast semantics, round-toward-zero**) for storing a computed result into a PWM duty register, a DAC code, or an ADC count, and `VCVT.F32.S32` (signed int → float) for lifting a raw ADC sample into the FPU before any filtering math. The fixed-point forms (`#fbits`) are how you keep Q-format DSP code in float-free hot loops, and the `VCVTB`/`VCVTT` half-precision forms are how you halve memory traffic for sensor blobs without giving up FPU throughput. Without `VCVT` you'd be hand-rolling shift/mask/scale code per cast — many cycles per conversion instead of one.


`<Tdest>.<Tsrc>` pairs supported by FPv5-SP: `F32.S32`, `F32.U32`, `S32.F32`, `U32.F32`,
`F32.S16`, `F32.U16`, `S16.F32`, `U16.F32` (fixed-point), and the F16 ↔ F32 forms above.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | dest single-prec FPU reg | S0–S31 |
| `<Sm>` | source single-prec FPU reg | S0–S31; for fixed-point `<Sd>` is also the source |
| `#<fbits>` | fraction-bit count | 1–16 for `S16/U16`, 1–32 for `S32/U32` |
| `.F16` | half-precision | encoded in low or high 16 bits of an S register |

## Operation (pseudocode)

```text
case form of
  F32.S32 / F32.U32:   Sd = ConvertIntToF32(Sm, signed?)        // exact (no rounding needed)
  S32.F32 / U32.F32:   Sd = ConvertF32ToInt(Sm, RoundTowardZero) // !! default is RTZ, not FPSCR
  F32.{S,U}{16,32} fix: Sd = Sm * 2^(-fbits) as F32
  {S,U}{16,32}.F32 fix: Sd = round(Sm * 2^(fbits)) as int, RTZ
  F32.F16 (B/T):       Sd = WidenHalfToSingle(half_of_Sm)
  F16.F32 (B/T):       half_of_Sd = NarrowSingleToHalf(Sm, FPSCR rounding)
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates APSR. May raise FPSCR cumulative exceptions: `IXC` (inexact),
`IOC` (invalid — e.g. NaN or out-of-range float→int), `UFC`/`OFC` for F16 narrowing.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | float ↔ integer |
| T1 | 32-bit | float ↔ fixed-point (with `#fbits`) |
| T1 | 32-bit | F16 ↔ F32 (`VCVTB`/`VCVTT`) |

All FPU encodings are 32-bit Thumb-2.

## Exceptions / faults

- UsageFault if FPU disabled (`CPACR.CP10/CP11 ≠ 0b11`) or `FPCCR.LSPACT` mishandled.
- No memory access — no alignment faults.
- FPSCR `IOC` set (and result becomes the saturated integer) when a float→int conversion
  is NaN or overflows. With trap enable bits clear (the default), execution continues.

## Example


### Example 1 — round-trip float ↔ int ↔ Q16 ↔ half

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VCVT demo: float -> int -> Q16 fixed -> back to float
    vmov.f32   s0, #1.5            @ s0 = 1.5f
    vcvt.s32.f32 s1, s0            @ s1 = (int)1.5  -> 1   (round toward zero)
    vmov         s2, s1            @ copy: fixed-point form needs Sd == Sm
    vcvt.f32.s32 s2, s2, #16       @ s2 = 1 * 2^-16 = 1/65536  (Q16 -> float)
    vcvt.s32.f32 s2, s2, #16       @ s2 = round(s2 * 2^16) = 1 (float -> Q16)
    @ Pack/unpack a half-precision value:
    vcvtb.f16.f32 s4, s0           @ low half of s4 = (half)1.5
    vcvtb.f32.f16 s5, s4           @ s5 = widen(low half of s4) = 1.5f
loop:
    b   loop
```

**Walkthrough:**

1. `vmov.f32 s0,#1.5` — load the immediate 1.5 into s0.
2. `vcvt.s32.f32 s1,s0` — float→int with the *default* round-toward-zero, so 1.5 becomes 1 (use [VCVTR](VCVTR.md) to round by FPSCR instead).
3. `vmov s2,s1` then `vcvt.f32.s32 s2,s2,#16` — the fixed-point form requires the same register for source and destination, so we copy first. Treat s2 as a Q16 fixed-point integer (16 fraction bits) and produce the equivalent float `1 × 2⁻¹⁶`.
4. `vcvt.s32.f32 s2,s2,#16` — the inverse: float → Q16 integer, again RTZ.
5. `vcvtb.f16.f32 s4,s0` — narrow s0 to half-precision and write it into the **bottom** 16 bits of s4 (top half is preserved). Use `vcvtt` for the top half.
6. `vcvtb.f32.f16 s5,s4` — widen the half stored in the bottom half of s4 back to single-precision.

This is the part that bites people: **`VCVT` on its own ignores FPSCR rounding for
float→int**. Use [VCVTR](VCVTR.md) for FPSCR-mode rounding, or
[VCVTA](VCVTA.md) / [VCVTN](VCVTN.md) / [VCVTP](VCVTP.md) / [VCVTM](VCVTM.md)
for explicit rounding modes.

### Example 2 — float PID output → 16-bit signed DAC code

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  pid_to_dac
    .thumb_func
pid_to_dac:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ s0 = float PID output already clamped to [-2048.0, +2047.0]
    vcvt.s32.f32 s1, s0           @ s1 = (int)s0  (round toward zero)
    vmov         r0, s1           @ r0 holds the signed 16-bit DAC code
    bx           lr
```

**Walkthrough:**

1. The PID output arrives in `s0` already clamped to a 12-bit signed range.
2. `vcvt.s32.f32 s1,s0` truncates it to a signed 32-bit integer using the C-cast rounding mode (round-toward-zero) — exactly what most DAC drivers expect.
3. `vmov r0,s1` lifts the integer out of the FPU and into a core register so the caller can write it to the DAC's data register.

## See also

- [VCVTR](VCVTR.md) — float→int using current FPSCR rounding mode
- [VCVTA](VCVTA.md), [VCVTN](VCVTN.md), [VCVTP](VCVTP.md), [VCVTM](VCVTM.md) — explicit rounding-mode conversions
- [VRINTZ](VRINTZ.md) — round float→float (no integer conversion)
- [VMOV](VMOV.md) — move/initialise FPU registers

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VCVT, VCVTB, VCVTT (between floating-point and integer / fixed-point / half-precision)*.
