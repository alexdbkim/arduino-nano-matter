# VCVTP — convert float→integer, round toward +∞ (ceiling)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP (FPv5-SP)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None (FPU must be enabled)
- **Secure-state required:** No

## Synopsis

```text
VCVTP.S32.F32   <Sd>, <Sm>
VCVTP.U32.F32   <Sd>, <Sm>
```

**When you'd actually use this** is when you need `(int)ceilf(x)` in one instruction. The mnemonic: **P = Plus-infinity = ceiling** — always rounds *up* the number line, so 2.1→3 and −2.9→−2 (toward zero for negatives). Typical contexts: `ceil(samples / buffer_size)` for "how many buffers do I need to hold N samples?", conservative cap-at-ceiling in resource sizing, and any allocation count where rounding down would under-provision. Without it you'd compute `-VCVTM(-x)` or branch on the fractional part — many cycles per ceil instead of one opcode.


Unconditional. Equivalent to `(int)ceilf(x)`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination single-prec FPU reg | S0–S31; holds 32-bit integer result |
| `<Sm>` | source single-prec FPU reg | S0–S31; F32 input |

## Operation (pseudocode)

```text
Sd = ConvertF32ToInt(Sm, RoundTowardPlusInfinity,
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
| T1 | 32-bit | float→signed/unsigned 32-bit integer, round toward +∞ |

32-bit Thumb-2 only.

## Exceptions / faults

- UsageFault if FPU disabled.
- FPSCR `IOC`, `IXC` as for other `VCVT` integer forms.

## Example


### Example 1 — round UP (toward +∞)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VCVTP demo: always round UP (toward +infinity)
    ldr           r0, =0x40066666  @ bits of 2.1f
    vmov          s0, r0
    vcvtp.s32.f32 s1, s0       @ s1 =  3
    ldr           r0, =0xC0399999  @ bits of -2.9f
    vmov          s2, r0
    vcvtp.s32.f32 s3, s2       @ s3 = -2  (ceil(-2.9) = -2, not -3)
    vmov.f32      s4, #5.0
    vcvtp.s32.f32 s5, s4       @ s5 =  5  (already integral, no change)
loop:
    b   loop
```

**Walkthrough:**

1. `vcvtp.s32.f32 s1,s0` — 2.1 rounds up to 3.
2. `vcvtp.s32.f32 s3,s2` — −2.9 rounds toward +∞, i.e. toward zero in this case → −2.
3. `vcvtp.s32.f32 s5,s4` — exactly representable integer is unchanged; `IXC` not set.

This is `ceilf` in one instruction, no library call, no FPSCR fiddling.

### Example 2 — ceil(samples / buffer_size) for buffer count

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  buffers_needed
    .thumb_func
buffers_needed:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ s0 = (float)total_samples / (float)buffer_size
    vcvtp.s32.f32 s1, s0          @ s1 = ceilf(s0)  (always rounds up)
    vmov          r0, s1
    bx            lr
```

**Walkthrough:**

1. The caller computes `total_samples / buffer_size` in float — for 1000/256 = 3.906… we'd under-allocate if we truncated.
2. `vcvtp.s32.f32 s1,s0` rounds 3.906 up to 4, the actual number of buffers needed.
3. For negative inputs `VCVTP` rounds toward zero (−2.9 → −2), which is the IEEE-754 ceiling — almost never what allocation code wants, so clamp `s0 ≥ 0` first.

## See also

- [VCVTM](VCVTM.md) — round toward −∞ (the floor)
- [VCVTN](VCVTN.md) — round to nearest, ties to even
- [VCVTA](VCVTA.md) — round to nearest, ties away from zero
- [VCVT](VCVT.md) — round toward zero (truncation)
- [VRINTP](VRINTP.md) — same rounding mode, float→float

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VCVTA, VCVTN, VCVTP, VCVTM (floating-point to integer with directed rounding)*.
