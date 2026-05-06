# VMUL — floating-point multiply (single precision)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only — `.F64` form is unavailable on EFR32MG24.

## Synopsis

```text
VMUL.F32 <Sd>, <Sn>, <Sm>
```

**When you'd actually use this** is for any per-sample scaling — applying a calibration gain, mixing two control terms (`u = Kp*err`), squaring a coordinate before a sum-of-squares, or weighting taps in an FIR. Each `VMUL` rounds once; if a multiply is immediately followed by an add or subtract, prefer `VFMA`/`VFMS` for one rounding instead of two. The classic alternative — fixed-point Q-format math — is faster on cores *without* a hardware FPU, but on the M33 with FPv5-SP a `VMUL.F32` is a single pipelined cycle and beats the Q15 ceremony for most code. Standard CPACR caveat first: with the FPU disabled (`CP10/CP11 ≠ 0b11`), the first `vmul.f32` UsageFaults.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination | S0–S31 |
| `<Sn>` | multiplicand | S0–S31 |
| `<Sm>` | multiplier | S0–S31 |

## Operation (pseudocode)

```text
CheckVFPEnabled();
Sd = FPMul(Sn, Sm, FPSCR);
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR untouched. Inexact / overflow / underflow bits set in `FPSCR`.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VMUL.F32 Sd, Sn, Sm` |

## Exceptions / faults

- UsageFault (`NOCP`) if FPU disabled.
- IEEE exceptions latched in FPSCR (no trap unless explicitly enabled — Cortex-M33 doesn't trap).

## Example

### Example 1 — scale a sample by a gain factor

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VMUL demo: scale a sample by a gain factor
    vmul.f32 s2, s0, s1      @ S2 = sample * gain
    vmul.f32 s2, s2, s1      @ S2 *= gain   (apply twice)
loop:
    b   loop
```

**Walkthrough:**

1. `vmul.f32 s2, s0, s1` — single-precision product with one IEEE rounding.
2. `vmul.f32 s2, s2, s1` — chained multiplies each round independently. If you're multiplying then adding, prefer `VFMA` for one combined rounding.

### Example 2 — sum of squares for a 3-axis acceleration vector

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VMUL demo 2: |g|^2 = gx*gx + gy*gy + gz*gz   (pre-sqrt magnitude)
    @ S0=gx, S1=gy, S2=gz ; result in S3
    vmul.f32 s3, s0, s0      @ S3 = gx*gx
    vmul.f32 s4, s1, s1      @ S4 = gy*gy
    vadd.f32 s3, s3, s4      @ S3 += gy*gy
    vmul.f32 s4, s2, s2      @ S4 = gz*gz
    vadd.f32 s3, s3, s4      @ S3 += gz*gz   (= |g|^2)
loop:
    b   loop
```

**Walkthrough:**

1. Three independent `VMUL`s feed two `VADD`s — the FPU pipelines them so the visible cost is roughly five cycles end-to-end.
2. Pass `S3` to `VSQRT` next if you need the magnitude itself; many tilt-compensation routines actually only compare squared magnitudes and skip the square root entirely.
3. The fused-multiply-add equivalent (`vmul`+`vfma`+`vfma`) shaves two roundings — useful when the inputs are very small or very large and the cancellation in `VADD` would otherwise lose bits.

## See also

- [VDIV](VDIV.md) — companion divide
- [VNMUL](VNMUL.md) — negated product
- [VMLA](VMLA.md), [VFMA](VFMA.md) — multiply-add

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VMUL (floating-point)*.
