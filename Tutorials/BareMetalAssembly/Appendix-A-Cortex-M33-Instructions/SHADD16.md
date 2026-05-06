# SHADD16 — signed halving per-lane add of packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SHADD16 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this**: `SHADD16` is the "average two packed int16 streams without overflowing" trick. Drop it into a stereo mixer when you want `(left_a + left_b)/2` and `(right_a + right_b)/2` in one cycle, or into a 2×-downsampler that combines adjacent halfword samples. Because the right-shift happens *inside* the add, two `0x7FFF` lanes simply produce `0x7FFF` — no saturation gymnastics needed. Without `SHADD16` you'd `SXTH` each half into a 32-bit register, `ADD`, `ASR #1`, and repack — five instructions and two scratch registers replaced by one cycle.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | `R0`–`R12`, `LR` (not `PC`/`SP`) |
| `<Rn>` | first source GPR | same constraints as `<Rd>` |
| `<Rm>` | second source GPR | same constraints as `<Rd>` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    for i in 0..1:
        x = SInt(Rn<lane i>) + SInt(Rm<lane i>)
        Rd<lane i> = (x >> 1)<15:0>     // arithmetic shift
```

`SHADD16` treats each 32-bit register as 2× 16-bit lanes packed in each 32-bit register and applies the halving signed (result = (a±b) >> 1) rule independently to every lane.

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

### Example 1 — Halving two packed int16 sample pairs

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Gain reduction by 0.5: average two int16 sample pairs without overflow.
    movw    r1, #0x7fff
    movt    r1, #0x7fff
    movw    r2, #0x7fff
    movt    r2, #0x7fff
    shadd16 r0, r1, r2          @ r0[lane] = (r1[lane] + r2[lane]) >> 1, signed; never overflows
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `shadd16 r0, r1, r2` treats each register as 2 packed halfword lanes and added them lane-by-lane.
3. Each lane result is **arithmetic-shifted right by 1** so the sum cannot overflow.

### Example 2 — Stereo audio midpoint mix without overflow

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Mix two stereo int16 samples (L|R packed in each register) into a midpoint pair.
    @ r1 = source A: lo=L_a, hi=R_a;  r2 = source B: lo=L_b, hi=R_b.
    movw    r1, #0x4000           @ L_a = +16384
    movt    r1, #0xC000           @ R_a = -16384
    movw    r2, #0x2000           @ L_b =  +8192
    movt    r2, #0xE000           @ R_b =  -8192
    shadd16 r0, r1, r2            @ r0 = midpoint: (L_a+L_b)/2 | (R_a+R_b)/2
loop:
    b       loop
```

**Walkthrough:**

1. Each register holds one stereo frame: low halfword = L channel, high halfword = R channel.
2. `shadd16` adds L_a+L_b and R_a+R_b in parallel, then arithmetic-shifts each lane right by 1.
3. The lane sums `+16384 + +8192 = +24576` and `−16384 + −8192 = −24576` momentarily exceed nothing, but the built-in `>>1` produces `+12288` and `−12288` — both safely back inside int16 range with no `SSAT` or widening required.

## See also

- [SHADD8](SHADD8.md) — same family
- [SHSUB8](SHSUB8.md) — same family
- [SHSUB16](SHSUB16.md) — same family
- [PKHBT](PKHBT.md) — rebuild a packed halfword pair after halving

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SHADD16*.
