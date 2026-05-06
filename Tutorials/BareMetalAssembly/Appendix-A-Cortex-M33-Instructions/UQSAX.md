# UQSAX — unsigned saturating exchange-then-sub-high/add-low on packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UQSAX <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `UQSAX` mirrors `UQASX`: **top half of result = top half of `Rn` MINUS bottom half of `Rm` (floor-zero); bottom half of result = bottom half of `Rn` PLUS top half of `Rm` (clamp 0xFFFF)**. It's the partner instruction in any unsigned cross-lane butterfly — for example the "diff on hi, sum on lo" half of a packed mid-side encoder over unsigned 16-bit samples, or asymmetric mixing of two packed sensor channels where one direction must clamp at zero and the other at the unsigned max. Without `UQSAX` the same shuffle costs 3–4 instructions and a manual clamp pair.

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
    Rd<31:16> = UnsignedSat(h, 16)
    Rd<15:0>  = UnsignedSat(l, 16)
```

`UQSAX` treats each 32-bit register as two 16-bit lanes packed in each 32-bit register (halves swapped on Rm) and applies the unsigned saturating (clamps to lane range) rule independently to every lane.

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

### Example 1 — minimal packed-halfword unsigned cross subtract/add

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ UQSAX: reverse-cross sub/add on packed halfwords.
    movw    r1, #0x0005
    movt    r1, #0x0003
    movw    r2, #0x0002
    movt    r2, #0x0001
    uqsax    r0, r1, r2          @ r0[hi]=r1[hi] − r2[lo], r0[lo]=r1[lo] + r2[hi]
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `uqsax r0, r1, r2` exchanges the halves of `r2` first, then computes `r0[hi] = r1[hi] − r2[lo]` and `r0[lo] = r1[lo] + r2[hi]`.
3. Each half is then **saturated** to the unsigned 16-bit range `[0, 65535]`.

### Example 2 — unsigned cross-lane mid-side encoder step

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Mirror of uqasx: hi = uqsat(Rn_hi - Rm_lo), lo = uqsat(Rn_lo + Rm_hi).
    @ Useful as the "diff on top, sum on bottom" cross half of an unsigned
    @ packed encoder when channels arrive swapped between Rn and Rm.
    movw    r0, #0x3000         @ Rn lo
    movt    r0, #0xC000         @ Rn hi
    movw    r1, #0x4000         @ Rm lo
    movt    r1, #0x2000         @ Rm hi
    uqsax   r2, r0, r1          @ hi = uqsat(0xC000 - 0x4000) = 0x8000
                                @ lo = uqsat(0x3000 + 0x2000) = 0x5000
loop:
    b   loop
```

**Walkthrough:**

1. `r0` and `r1` each pack two unsigned 16-bit channels; `uqsax` does the cross "subtract on hi, add on lo" with independent unsigned saturation.
2. The high lane gives `0x8000` (no clamp needed); the low lane gives `0x5000` (no clamp needed). Had the subtract gone negative the hi lane would floor at `0`; had the add overflowed `0xFFFF` the lo lane would saturate.
3. Without `uqsax` the same shuffle is `PKHBT`/`PKHTB` + `UQSUB16` + `UQADD16`-equivalent — multiple cycles versus one.

## See also

- [UQADD8](UQADD8.md) — same family
- [UQADD16](UQADD16.md) — same family
- [UQSUB8](UQSUB8.md) — same family
- [UQASX](UQASX.md) — mirror operation (add on hi, subtract on lo)
- [USAT](USAT.md) — scalar unsigned saturation

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *UQSAX*.
