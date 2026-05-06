# UQASX — unsigned saturating exchange-then-add-high/sub-low on packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UQASX <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `UQASX` is the unsigned cousin of `QASX`. Lane layout: **top half of result = top half of `Rn` PLUS bottom half of `Rm` (clamped at 0xFFFF); bottom half of result = bottom half of `Rn` MINUS top half of `Rm` (clamped at 0)**. Useful when you're doing complex-style cross arithmetic on unsigned packed 16-bit data — think 2D unsigned vector cross-mix, dual-channel sensor fusion where you add one cross-coupling and subtract the other, or a fixed-point algorithm operating on positive Q15 magnitudes. Without `UQASX`, the same job is a `PKHBT` + `UQADD16` + `UQSUB16` style sequence — multiple cycles versus one.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | `R0`–`R12`, `LR` (not `PC`/`SP`) |
| `<Rn>` | first source GPR | same constraints as `<Rd>` |
| `<Rm>` | second source GPR | same constraints as `<Rd>` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    h = UInt(Rn<31:16>) + UInt(Rm<15:0>)
    l = UInt(Rn<15:0>)  − UInt(Rm<31:16>)
    Rd<31:16> = UnsignedSat(h, 16)
    Rd<15:0>  = UnsignedSat(l, 16)
```

`UQASX` treats each 32-bit register as two 16-bit lanes packed in each 32-bit register (halves swapped on Rm) and applies the unsigned saturating (clamps to lane range) rule independently to every lane.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never sets `N`/`Z`/`C`/`V`/`GE`. Crucially — and unlike scalar `QADD`/`QSUB` — the SIMD saturating variants do **not** set `APSR.Q` either. Saturation is silent; if you need to detect it, compare the result yourself.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | Thumb-2 only — there is **no** 16-bit encoding |

There is no 16-bit Thumb encoding for this instruction; the assembler always emits the 32-bit form.

## Exceptions / faults

- (none) — register-to-register only, no memory access.

## Example

### Example 1 — minimal packed-halfword unsigned cross add/subtract

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ UQASX: cross add/sub on packed halfwords (used by complex-number kernels).
    movw    r1, #0x0005
    movt    r1, #0x0003
    movw    r2, #0x0002
    movt    r2, #0x0001
    uqasx    r0, r1, r2          @ r0[hi]=r1[hi] + r2[lo], r0[lo]=r1[lo] − r2[hi]
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `uqasx r0, r1, r2` exchanges the halves of `r2` first, then computes `r0[hi] = r1[hi] + r2[lo]` and `r0[lo] = r1[lo] − r2[hi]`.
3. Each half is then **saturated** to the unsigned 16-bit range `[0, 65535]`.

### Example 2 — unsigned 2D vector cross-mix with floor-zero

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Packed unsigned (X,Y) vectors in r0 and r1: hi = Y, lo = X.
    @ uqasx mixes Y_a with X_b on top (clamp 0xFFFF) and X_a with -Y_b on
    @ bottom (clamp 0).  Useful in unsigned 2D fusion / shear-like steps.
    movw    r0, #0x4000         @ X_a = 0x4000
    movt    r0, #0xF000         @ Y_a = 0xF000
    movw    r1, #0x2000         @ X_b = 0x2000
    movt    r1, #0x8000         @ Y_b = 0x8000
    uqasx   r2, r0, r1          @ hi = uqsat(Y_a + X_b), lo = uqsat(X_a - Y_b)
loop:
    b   loop
```

**Walkthrough:**

1. `r0` packs `Y_a` (high) and `X_a` (low); `r1` packs `Y_b` and `X_b`.
2. `uqasx` produces `r2_hi = uqsat(0xF000 + 0x2000) = 0xFFFF` (clamped at the unsigned 16-bit max) and `r2_lo = uqsat(0x4000 − 0x8000) = 0` (floored at zero).
3. The independent per-lane saturation means the saturating-high lane can't bleed into the floored-low lane — replacing this single instruction with `UXTH`/`UQADD`/`UQSUB`/repack would cost about 5 cycles.

## See also

- [UQADD8](UQADD8.md) — same family
- [UQADD16](UQADD16.md) — same family
- [UQSUB8](UQSUB8.md) — same family
- [UQSAX](UQSAX.md) — mirror operation (subtract on hi, add on lo)
- [USAT](USAT.md) — scalar unsigned saturation

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *UQASX*.
