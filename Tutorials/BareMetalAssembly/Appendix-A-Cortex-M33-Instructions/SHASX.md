# SHASX — signed halving exchange-then-add-high/sub-low on packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SHASX <Rd>, <Rn>, <Rm>
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | `R0`–`R12`, `LR` (not `PC`/`SP`) |
| `<Rn>` | first source GPR | same constraints as `<Rd>` |
| `<Rm>` | second source GPR | same constraints as `<Rd>` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    h = SInt(Rn<31:16>) + SInt(Rm<15:0>)
    l = SInt(Rn<15:0>)  − SInt(Rm<31:16>)
    Rd<31:16> = (h >> 1)<15:0>     // arithmetic shift
    Rd<15:0>  = (l >> 1)<15:0>
```

`SHASX` treats each 32-bit register as two 16-bit lanes packed in each 32-bit register (halves swapped on Rm) and applies the halving signed (result = (a±b) >> 1) rule independently to every lane.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never sets any flag. Halving guarantees the result fits, so there is nothing to report.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | Thumb-2 only — there is **no** 16-bit encoding |

There is no 16-bit Thumb encoding for this instruction; the assembler always emits the 32-bit form.

## Exceptions / faults

- (none) — register-to-register only, no memory access.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SHASX: cross add/sub on packed halfwords (used by complex-number kernels).
    movw    r1, #0x0005
    movt    r1, #0x0003
    movw    r2, #0x0002
    movt    r2, #0x0001
    shasx    r0, r1, r2          @ r0[hi]=r1[hi] + r2[lo], r0[lo]=r1[lo] − r2[hi]
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `shasx r0, r1, r2` exchanges the halves of `r2` first, then computes `r0[hi] = r1[hi] + r2[lo]` and `r0[lo] = r1[lo] − r2[hi]`.
3. Each half result is **arithmetic-shifted right by 1** (signed halving) so the answer always fits.

## See also

- [SHADD8](SHADD8.md) — same family
- [SHADD16](SHADD16.md) — same family
- [SHSUB8](SHSUB8.md) — same family
- [SHSAX](SHSAX.md) — mirror operation (subtract on hi, add on lo)
- [PKHBT](PKHBT.md) — rebuild a packed halfword pair after halving

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SHASX*.
