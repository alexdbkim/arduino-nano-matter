# VNMUL — floating-point negated multiply (single precision)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only. `.F64` is unavailable on this part.

## Synopsis

```text
VNMUL.F32 <Sd>, <Sn>, <Sm>     @ Sd = -(Sn * Sm)
```

**When you'd actually use this** is when you specifically want `−(a*b)` — typically in MAC chains where you're subtracting a product from a running total (`y -= a*b`) or building negated cross-terms in a rotation matrix. `VNMUL` produces the negated product in one cycle, no separate `VNEG`. For the *fused* (single-rounding) form `acc = acc − a*b`, prefer `VFMS`; `VNMUL` shines when you don't already have the accumulator in `Sd` or you want plain two-operand semantics. CPACR-first as always: no `VNMUL` will execute until `CP10/CP11 = 0b11`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination | S0–S31 |
| `<Sn>` | multiplicand | S0–S31 |
| `<Sm>` | multiplier | S0–S31 |

## Operation (pseudocode)

```text
CheckVFPEnabled();
Sd = FPNeg(FPMul(Sn, Sm, FPSCR));
```

The negation is a sign-bit flip on the rounded product — it's exact and free.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR untouched. FPSCR exception bits update from the multiply.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VNMUL.F32 Sd, Sn, Sm` |

## Exceptions / faults

- UsageFault (`NOCP`) if FPU disabled.

## Example

### Example 1 — subtract `a*b` from a running total

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VNMUL demo: subtract a*b from a running total in one op
    @ S0 = total, S1 = a, S2 = b
    vnmul.f32 s3, s1, s2     @ S3 = -(a*b)
    vadd.f32  s0, s0, s3     @ total += -(a*b)  i.e. total -= a*b
loop:
    b   loop
```

**Walkthrough:**

1. `vnmul.f32 s3, s1, s2` — compute `a*b` and flip the sign in one go. Saves a separate `VNEG` after `VMUL`.
2. `vadd.f32 s0, s0, s3` — fold into accumulator. For one-rounding fused form, see `VFMS` (Sd = Sd − Sn*Sm).

### Example 2 — residual update in a least-squares step

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VNMUL demo 2: r = y - a*x   (residual = target - prediction)
    @ S0 = y (target), S1 = a (slope), S2 = x (input) ; result in S3
    vnmul.f32 s3, s1, s2     @ S3 = -(a*x)
    vadd.f32  s3, s0, s3     @ S3 = y + (-a*x) = y - a*x  (residual)
    vmul.f32  s4, s3, s3     @ S4 = r^2  (cost contribution)
loop:
    b   loop
```

**Walkthrough:**

1. `vnmul.f32 s3, s1, s2` — one cycle: multiply and flip sign together. Saves the `vmul`+`vneg` pair.
2. `vadd.f32 s3, s0, s3` — `y + (−a*x)` is mathematically the same as `y − a*x`, with the multiply's sign already baked in.
3. `vmul.f32 s4, s3, s3` — squaring the residual is the typical next step in an online least-squares update; combining with `VFMA` would let you accumulate into a sum-of-squared-residuals with a single rounding.

## See also

- [VMUL](VMUL.md) — non-negated form
- [VNEG](VNEG.md) — sign flip on its own
- [VFMS](VFMS.md), [VFNMA](VFNMA.md) — fused negative-multiply-add variants

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VNMUL*.
