# VMLA — floating-point multiply-accumulate (single precision, two roundings)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only. `.F64` is **not** available on EFR32MG24.

`VMLA` rounds **twice** (once after the multiply, once after the add). For a single-rounded fused form, use [`VFMA`](VFMA.md).

## Synopsis

```text
VMLA.F32 <Sd>, <Sn>, <Sm>      @ Sd = Sd + (Sn * Sm)
```

**When you'd actually use this** today is mostly when you specifically need strict-IEEE behaviour that **must round twice** — code ported from older FPv4 cores, bit-exact reproduction of a reference C implementation compiled without `-ffp-contract`, or test vectors that pin down a particular rounded intermediate. For new DSP code the fused `VFMA` is strictly more accurate (one rounding instead of two) at the same throughput, and that's what compilers emit whenever `fma()` semantics are allowed. Reach for `VMLA` only when the legacy round-mul-then-round-add path is the actual specification — otherwise prefer `VFMA` and pocket the half-an-ULP-per-tap precision win.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | accumulator (read+write) | S0–S31 |
| `<Sn>` | multiplicand | S0–S31 |
| `<Sm>` | multiplier | S0–S31 |

## Operation (pseudocode)

```text
CheckVFPEnabled();
prod = FPMul(Sn, Sm, FPSCR);   // round #1
Sd   = FPAdd(Sd, prod, FPSCR); // round #2
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR untouched; FPSCR cumulative bits may set.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VMLA.F32 Sd, Sn, Sm` |

## Exceptions / faults

- UsageFault (`NOCP`) if FPU disabled.

## Example

### Example 1 — 4-element dot product (legacy two-rounding)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VMLA demo: 4-element dot product
    @ S0..S3 = a[0..3], S4..S7 = b[0..3], S8 = accumulator
    vmul.f32 s8, s0, s4      @ acc  = a0*b0
    vmla.f32 s8, s1, s5      @ acc += a1*b1
    vmla.f32 s8, s2, s6      @ acc += a2*b2
    vmla.f32 s8, s3, s7      @ acc += a3*b3
loop:
    b   loop
```

**Walkthrough:**

1. `vmul.f32 s8, s0, s4` — seed the accumulator (avoids needing acc=0).
2. Three `vmla.f32` — each adds the next product to the running sum. Two roundings per step; for a numerically tighter dot-product use `VFMA`.

### Example 2 — Horner polynomial step `acc = c + acc*x`

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  horner_step
    .thumb_func
horner_step:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ One Horner step: new_acc = c + old_acc * x   (two roundings)
    @ S0 = c (next coefficient, becomes new_acc)
    @ S1 = old_acc, S2 = x
    vmla.f32 s0, s1, s2      @ S0 = c + old_acc*x
    bx       lr
```

**Walkthrough:**

1. `vmla.f32 s0, s1, s2` — round #1 for `old_acc*x`, round #2 for the add to `c`. An N-degree polynomial therefore eats 2N roundings via `VMLA` versus N via `VFMA`. When the coefficients span many orders of magnitude (think a Chebyshev approximation for `expf`), the doubled error budget can shift the last two bits of the result — visible in unit tests that bit-compare against a reference implementation.

## See also

- [VFMA](VFMA.md) — same shape, **single** rounding
- [VMLS](VMLS.md) — subtract product instead
- [VNMLA](VNMLA.md), [VNMLS](VNMLS.md) — negated accumulator forms
- [VMUL](VMUL.md), [VADD](VADD.md)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VMLA (floating-point)*.
