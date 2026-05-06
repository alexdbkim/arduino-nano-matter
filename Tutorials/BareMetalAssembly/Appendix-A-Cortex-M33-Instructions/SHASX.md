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

**When you'd actually use this**: `SHASX` is the scaled-radix-2 FFT butterfly's "free" companion: it cross-pairs the halves of `Rm` with the halves of `Rn`, sums one pair, subtracts the other, and pre-divides each result by 2. That `>>1` is the magic — the standard FFT trick of halving every stage's output keeps an N-point transform inside int16 range without per-stage rescaling. Without `SHASX` you'd `ROR #16` to swap halves of `Rm`, do separate `SADD16`/`SSUB16`, then `ASR #1` each lane through unpack/repack — easily six instructions replaced by one.

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

### Example 1 — Cross add/sub on packed halfwords

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

### Example 2 — One stage of a scaled radix-2 FFT butterfly

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Scaled butterfly: produce (a_hi + b_hi)/2 in r0[hi] and (a_lo - b_lo)/2 in r0[lo]
    @ in a single cycle. Operand b is pre-swapped so SHASX undoes the swap during the op.
    movw    r1, #0x0040           @ a_lo (real)  = +64
    movt    r1, #0x0020           @ a_hi (imag)  = +32
    movw    r2, #0x0008           @ r2[lo] paired with a_hi  (= b_hi value, +8)
    movt    r2, #0x0004           @ r2[hi] paired with a_lo  (= b_lo value, +4)
    shasx   r0, r1, r2            @ r0[hi]=(a_hi+b_hi)/2=+20, r0[lo]=(a_lo-b_lo)/2=+30
loop:
    b       loop
```

**Walkthrough:**

1. `r1` holds one complex sample `a` (real in lo, imag in hi); `r2` holds `b` with its halves pre-swapped so the cross-pairing of `SHASX` lines lanes back up correctly.
2. `shasx` computes `r0[hi] = (a_hi + b_hi)>>1` and `r0[lo] = (a_lo − b_lo)>>1` in parallel.
3. The built-in halving is the entire reason a "scaled FFT" can run end-to-end in int16 without overflow checks — every stage shrinks the magnitude by 2, exactly compensating the doubling that an unscaled butterfly would cause.

## See also

- [SHADD8](SHADD8.md) — same family
- [SHADD16](SHADD16.md) — same family
- [SHSUB8](SHSUB8.md) — same family
- [SHSAX](SHSAX.md) — mirror operation (subtract on hi, add on lo)
- [PKHBT](PKHBT.md) — rebuild a packed halfword pair after halving

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SHASX*.
