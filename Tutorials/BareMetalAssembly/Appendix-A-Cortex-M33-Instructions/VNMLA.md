# VNMLA — floating-point negated multiply-accumulate (single precision)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only — `.F64` form is unavailable on EFR32MG24. Two roundings (mul, then add). For single rounding see [`VFNMA`](VFNMA.md).

## Synopsis

```text
VNMLA.F32 <Sd>, <Sn>, <Sm>     @ Sd = -Sd - (Sn * Sm)
```

This is **both** the accumulator and the product negated — equivalent to `Sd = -(Sd + Sn*Sm)`.

**When you'd actually use this** is in numerical kernels that explicitly accumulate negated products — Givens rotations, certain in-place QR/Cholesky updates, or signal-flow graphs where the sign convention is folded into the accumulate step (saving a separate `VNEG` instruction). The two-rounding behaviour is rarely the *goal*; if you have a choice the modern fused `VFNMA` is strictly more accurate at the same throughput. The main reason to know `VNMLA` today is so you recognise "negate-and-add-product" as one instruction in older codegen rather than reading it as three separate ops.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | accumulator (read+write) | S0–S31 |
| `<Sn>` | multiplicand | S0–S31 |
| `<Sm>` | multiplier | S0–S31 |

## Operation (pseudocode)

```text
CheckVFPEnabled();
prod = FPMul(Sn, Sm, FPSCR);
Sd   = FPSub(FPNeg(Sd), prod, FPSCR);   // -Sd - prod
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR untouched.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VNMLA.F32 Sd, Sn, Sm` |

## Exceptions / faults

- UsageFault (`NOCP`) if FPU disabled.

## Example

### Example 1 — `-(c + a*b)` for a Givens-rotation kernel

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VNMLA demo: compute -(c + a*b) — useful in some Givens-rotation kernels
    @ S0 = c (acc), S1 = a, S2 = b
    vnmla.f32 s0, s1, s2     @ S0 = -S0 - a*b  =  -(c + a*b)
loop:
    b   loop
```

**Walkthrough:**

1. `vnmla.f32 s0, s1, s2` — flips the sign of both the running accumulator and the product, in one instruction. Niche but turns up in numerical libraries (e.g. some QR / SVD updates).

### Example 2 — fold a sign-flip into a multiply-accumulate

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  neg_macc
    .thumb_func
neg_macc:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ Combine VMLA + VNEG into one op: out = -(acc + a*b)
    @ S0 = acc (becomes out)
    @ S1 = a, S2 = b
    vnmla.f32 s0, s1, s2     @ S0 = -(acc + a*b)   (two roundings)
    bx        lr
```

**Walkthrough:**

1. `vnmla.f32 s0, s1, s2` — saves a separate `VNEG` after a `VMLA`, so the source expression `-(acc + a*b)` becomes one instruction in compiler output. Two roundings still apply (one for the multiply, one for the add); for tighter numerics around cancellation step up to `VFNMA` and lose the second round.

## See also

- [VMLA](VMLA.md) — un-negated form
- [VNMLS](VNMLS.md) — negate accumulator only
- [VFNMA](VFNMA.md) — fused, single-rounded counterpart

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VNMLA*.
