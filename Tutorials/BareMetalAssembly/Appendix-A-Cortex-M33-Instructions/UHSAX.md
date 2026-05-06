# UHSAX — unsigned halving exchange-then-sub-high/add-low on packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UHSAX <Rd>, <Rn>, <Rm>
```

**When you'd actually use this**: `UHSAX` is `UHASX`'s mirror: subtract on the hi lane, add on the lo lane, halved and unsigned. The use-case is the same family of cross-butterflies — magnitude-spectrum mixing, mirrored bilateral averaging — but with the lane pairing reversed (typical for the conjugate twiddle). The eureka is identical: there's no possibility of overflow because the result is mathematically `(±a ± b)/2`, which can't exceed the input range, so you never need to widen, mask, or saturate.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | `R0`–`R12`, `LR` (not `PC`/`SP`) |
| `<Rn>` | first source GPR | same constraints as `<Rd>` |
| `<Rm>` | second source GPR | same constraints as `<Rd>` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    h = UInt(Rn<31:16>) − UInt(Rm<15:0>)
    l = UInt(Rn<15:0>)  + UInt(Rm<31:16>)
    Rd<31:16> = (h >> 1)<15:0>     // logical shift
    Rd<15:0>  = (l >> 1)<15:0>
```

`UHSAX` treats each 32-bit register as two 16-bit lanes packed in each 32-bit register (halves swapped on Rm) and applies the halving unsigned (result = (a±b) >> 1) rule independently to every lane.

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

### Example 1 — Reverse-cross sub/add on packed unsigned halfwords

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ UHSAX: reverse-cross sub/add on packed halfwords.
    movw    r1, #0x0005
    movt    r1, #0x0003
    movw    r2, #0x0002
    movt    r2, #0x0001
    uhsax    r0, r1, r2          @ r0[hi]=r1[hi] − r2[lo], r0[lo]=r1[lo] + r2[hi]
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `uhsax r0, r1, r2` exchanges the halves of `r2` first, then computes `r0[hi] = r1[hi] − r2[lo]` and `r0[lo] = r1[lo] + r2[hi]`.
3. Each half result is **logical-shifted right by 1** (unsigned halving) so the answer always fits.

### Example 2 — Mirrored unsigned spectrum butterfly

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Mirrored butterfly on unsigned 16-bit bins:
    @   r0[hi] = (r1[hi] - r2[lo]) / 2,  r0[lo] = (r1[lo] + r2[hi]) / 2
    movw    r1, #0x00C0           @ bin a_lo = 0x00C0
    movt    r1, #0x0080           @ bin a_hi = 0x0080
    movw    r2, #0x0010           @ paired with a_hi
    movt    r2, #0x0020           @ paired with a_lo
    uhsax   r0, r1, r2            @ r0[hi]=(0x80-0x10)/2=0x38, r0[lo]=(0xC0+0x20)/2=0x70
loop:
    b       loop
```

**Walkthrough:**

1. Same packing convention as `UHASX`: `r2`'s halves cross-pair with `r1`'s during the op.
2. `uhsax` subtracts on the hi lane and adds on the lo lane; both lanes are `>>1`-halved.
3. The result lives in `uint16` regardless of inputs — that "no-overflow-by-construction" property is what lets a chain of conjugated-twiddle butterflies run without any `USAT` or rescaling.

## See also

- [UHADD8](UHADD8.md) — same family
- [UHADD16](UHADD16.md) — same family
- [UHSUB8](UHSUB8.md) — same family
- [UHASX](UHASX.md) — mirror operation (add on hi, subtract on lo)
- [PKHBT](PKHBT.md) — rebuild a packed halfword pair after halving

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *UHSAX*.
