# SHSAX — signed halving exchange-then-sub-high/add-low on packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SHSAX <Rd>, <Rn>, <Rm>
```

**When you'd actually use this**: `SHSAX` is the mirror twin of `SHASX` — it subtracts on the hi lane and adds on the lo lane, again with built-in halving. That's the butterfly you want when the twiddle factor is conjugated (the imaginary part flips sign), so the cross-pattern reverses. Same eureka: the result lives in 16 bits because `(a ± b)/2` cannot exceed the input range. Replacing the manual `ROR`-swap-add-sub-shift sequence with one cycle is a 5–6× speedup in inner FFT loops.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | `R0`–`R12`, `LR` (not `PC`/`SP`) |
| `<Rn>` | first source GPR | same constraints as `<Rd>` |
| `<Rm>` | second source GPR | same constraints as `<Rd>` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    h = SInt(Rn<31:16>) − SInt(Rm<15:0>)
    l = SInt(Rn<15:0>)  + SInt(Rm<31:16>)
    Rd<31:16> = (h >> 1)<15:0>     // arithmetic shift
    Rd<15:0>  = (l >> 1)<15:0>
```

`SHSAX` treats each 32-bit register as two 16-bit lanes packed in each 32-bit register (halves swapped on Rm) and applies the halving signed (result = (a±b) >> 1) rule independently to every lane.

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

### Example 1 — Reverse-cross sub/add on packed halfwords

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SHSAX: reverse-cross sub/add on packed halfwords.
    movw    r1, #0x0005
    movt    r1, #0x0003
    movw    r2, #0x0002
    movt    r2, #0x0001
    shsax    r0, r1, r2          @ r0[hi]=r1[hi] − r2[lo], r0[lo]=r1[lo] + r2[hi]
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `shsax r0, r1, r2` exchanges the halves of `r2` first, then computes `r0[hi] = r1[hi] − r2[lo]` and `r0[lo] = r1[lo] + r2[hi]`.
3. Each half result is **arithmetic-shifted right by 1** (signed halving) so the answer always fits.

### Example 2 — Scaled butterfly with conjugated twiddle

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Mirror butterfly used when the FFT twiddle is conjugated:
    @   r0[hi] = (a_hi - b_hi)/2,  r0[lo] = (a_lo + b_lo)/2
    movw    r1, #0x0040           @ a_lo = +64
    movt    r1, #0x0020           @ a_hi = +32
    movw    r2, #0x0008           @ r2[lo] paired with a_hi (=+8)
    movt    r2, #0x0004           @ r2[hi] paired with a_lo (=+4)
    shsax   r0, r1, r2            @ r0[hi]=(32-8)/2=+12, r0[lo]=(64+4)/2=+34
loop:
    b       loop
```

**Walkthrough:**

1. Same input layout as the `SHASX` butterfly, but the cross-pattern is reversed: `SHSAX` subtracts on the hi lane and adds on the lo lane.
2. Each lane is `>>1` inside the operation, so a stage of the FFT cannot overflow no matter what the twiddle sign is.
3. Pairing `SHASX` and `SHSAX` lets the inner kernel keep both real and imaginary halves of a butterfly in lockstep, with zero `SSAT` and zero per-stage shift code.

## See also

- [SHADD8](SHADD8.md) — same family
- [SHADD16](SHADD16.md) — same family
- [SHSUB8](SHSUB8.md) — same family
- [SHASX](SHASX.md) — mirror operation (add on hi, subtract on lo)
- [PKHBT](PKHBT.md) — rebuild a packed halfword pair after halving

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SHSAX*.
