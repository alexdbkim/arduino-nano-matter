# VFMS — fused multiply-subtract (single precision, single rounding)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only. Single-rounded counterpart of [`VMLS`](VMLS.md) — the negated multiply is added to the accumulator at infinite precision, then rounded once.

## Synopsis

```text
VFMS.F32 <Sd>, <Sn>, <Sm>      @ Sd = Sd + (-Sn * Sm)   [single rounding]
```

i.e. `Sd = Sd - Sn*Sm`, but with one round, not two.

**When you'd actually use this** — residual computations and IIR feedback paths where you must subtract a product from a running value with as little round-off as possible. Typical homes: iterative refinement (`r = b - A*x`), the feedback term of a Direct-Form-I IIR (`acc -= a1*y_prev`), Kalman innovation updates, and any control-loop error term that gets fed back into the next sample. The fused single-round subtract preserves the cancelling bits that two-round `VMLS` can lose entirely when the operands are close in magnitude. Reach for `VFMS` whenever you write `acc -= prod` in a numerical inner loop and care about long-term drift.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | accumulator (read+write) | S0–S31 |
| `<Sn>` | multiplicand (negated) | S0–S31 |
| `<Sm>` | multiplier | S0–S31 |

## Operation (pseudocode)

```text
CheckVFPEnabled();
Sd = FPMulAdd(Sd, FPNeg(Sn), Sm, FPSCR);   // single rounding
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR untouched.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VFMS.F32 Sd, Sn, Sm` |

## Exceptions / faults

- UsageFault (`NOCP`) if FPU disabled.

## Example

### Example 1 — regression residual `r = y - x*beta`

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VFMS demo: residual r = y - x*beta  with one rounding
    @ S0 = y (will become r), S1 = x, S2 = beta
    vfms.f32 s0, s1, s2      @ S0 = y - x*beta   (fused)
loop:
    b   loop
```

**Walkthrough:**

1. `vfms.f32 s0, s1, s2` — full residual in one fused op. Critical for iterative refinement loops where round-off in the residual would defeat the iteration.

### Example 2 — IIR Direct-Form-I feedback step

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  iir_step
    .thumb_func
iir_step:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ Feedback half of a biquad: acc = acc - a1 * y_prev
    @ S0 = acc (already holds the feed-forward sum)
    @ S1 = a1 (feedback coefficient), S2 = y_prev (last output)
    vfms.f32 s0, s1, s2      @ acc -= a1 * y_prev   (single rounding)
    bx      lr
```

**Walkthrough:**

1. `vfms.f32 s0, s1, s2` — the IIR feedback path is the most error-sensitive part of a biquad, because today's rounded output becomes tomorrow's `y_prev`. With one rounding per step the pole locations stay close to design; with two roundings (`VMLS`) a high-Q biquad can drift over thousands of samples, audibly detuning the filter or in extreme cases turning a stable pole unstable.

## See also

- [VMLS](VMLS.md) — two-rounding version
- [VFMA](VFMA.md) — fused add
- [VFNMS](VFNMS.md) — fused with negated accumulator

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VFMS*.
