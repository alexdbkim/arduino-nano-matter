# UHASX — unsigned halving exchange-then-add-high/sub-low on packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UHASX <Rd>, <Rn>, <Rm>
```

**When you'd actually use this**: `UHASX` is the unsigned, halving cross-add/sub butterfly — useful in magnitude-domain spectral processing (where bins are `uint16`) or in image kernels that combine "summed" and "crossed" pairs of unsigned channels with built-in scaling. The `(a ± b)/2` ensures the result fits back in the same 16-bit lane no matter how big the inputs were. Compared with the manual `ROR #16` + `UADD16`/`USUB16` + `LSR #1` chain, `UHASX` collapses the work to a single cycle with no temporaries.

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
    Rd<31:16> = (h >> 1)<15:0>     // logical shift
    Rd<15:0>  = (l >> 1)<15:0>
```

`UHASX` treats each 32-bit register as two 16-bit lanes packed in each 32-bit register (halves swapped on Rm) and applies the halving unsigned (result = (a±b) >> 1) rule independently to every lane.

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

### Example 1 — Cross add/sub on packed unsigned halfwords

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ UHASX: cross add/sub on packed halfwords (used by complex-number kernels).
    movw    r1, #0x0005
    movt    r1, #0x0003
    movw    r2, #0x0002
    movt    r2, #0x0001
    uhasx    r0, r1, r2          @ r0[hi]=r1[hi] + r2[lo], r0[lo]=r1[lo] − r2[hi]
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `uhasx r0, r1, r2` exchanges the halves of `r2` first, then computes `r0[hi] = r1[hi] + r2[lo]` and `r0[lo] = r1[lo] − r2[hi]`.
3. Each half result is **logical-shifted right by 1** (unsigned halving) so the answer always fits.

### Example 2 — Scaled magnitude-domain butterfly stage

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Scaled butterfly on unsigned 16-bit spectrum bins:
    @   r0[hi] = (r1[hi] + r2[lo]) / 2,  r0[lo] = (r1[lo] - r2[hi]) / 2
    movw    r1, #0x00C0           @ bin a_lo = 0x00C0
    movt    r1, #0x0080           @ bin a_hi = 0x0080
    movw    r2, #0x0010           @ b paired with a_hi
    movt    r2, #0x0020           @ b paired with a_lo
    uhasx   r0, r1, r2            @ r0[hi]=(0x80+0x10)/2=0x48, r0[lo]=(0xC0-0x20)/2=0x50
loop:
    b       loop
```

**Walkthrough:**

1. `r1` and `r2` carry pairs of unsigned spectral magnitudes; `r2` is laid out so its halves cross-pair with `r1` during the op.
2. `uhasx` adds the upper-cross pair, subtracts the lower-cross pair, and `>>1`s each lane in one shot.
3. Because each lane is `(a + b)/2` or `(a − b)/2`, the result is mathematically guaranteed to fit in 16 bits — no per-stage rescale, no `USAT`. That's exactly the property a multi-stage scaled butterfly chain depends on.

## See also

- [UHADD8](UHADD8.md) — same family
- [UHADD16](UHADD16.md) — same family
- [UHSUB8](UHSUB8.md) — same family
- [UHSAX](UHSAX.md) — mirror operation (subtract on hi, add on lo)
- [PKHBT](PKHBT.md) — rebuild a packed halfword pair after halving

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *UHASX*.
