# SMLABB — Signed 16×16 multiply (bottom half of `Rn` × bottom half of `Rm`), accumulate into `Ra`.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLABB <Rd>, <Rn>, <Rm>, <Ra>
```

**When you'd actually use this** is the multiply-accumulate inner loop of a Q15 FIR filter. With two int16 samples packed per word as `[T|B]` (top = bits 31:16, bottom = bits 15:0), `SMLABB` does one tap per cycle — multiply low-half sample × low-half coefficient, add to the running accumulator. The plain `MUL`+`ADD` sequence is two cycles and clobbers a temp register; without `SMLABB` you'd also need `SXTH` to sign-extend each half, dragging a single tap to four instructions. Packed Q15 storage plus `SMLABB`/`SMLATT` is the canonical inner loop of every Q15 FIR/biquad on Cortex-M33.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | R0–R12, LR; not PC/SP |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |
| `<Ra>` | accumulator GPR | R0–R12, LR |

## Operation (pseudocode)

```text
prod32 = SInt(Rn[15:0]) * SInt(Rm[15:0])
result = SInt(Ra) + prod32                 // 33-bit signed add
Rd = result[31:0]
if SignedOverflow(Ra, prod32) then APSR.Q = 1
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | ✓ |

Sets `Q` on signed overflow of the accumulate or dual-sum step. `N`, `Z`, `C`, `V` are never touched.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMLABB` Rd, Rn, Rm, Ra |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

## Example

### Example 1 — Single Q15 MAC step

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMLABB demo: biquad coefficient × state, low halves
    @ Pack a Q15 sample in r1[15:0], coefficient in r2[15:0]
    movs    r0, #0
    movw    r1, #0x4000         @ sample = 0.5 in Q15
    movw    r2, #0x2000         @ coeff  = 0.25 in Q15
    smlabb  r0, r1, r2, r0      @ r0 += sample * coeff (no shift)
loop:
    b   loop
```

**Walkthrough:**

1. Zero the accumulator.
2. Place Q15 values in the low halves of `r1` and `r2`. The high halves are ignored by `SMLABB`.
3. `smlabb` does `r0 = r0 + (int16)r1 * (int16)r2`. The product is a Q30 number; for Q15 audio you'd typically follow with a 1-bit left shift or use the `W` variants.

### Example 2 — 2-tap packed-Q15 FIR loop body

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ One iteration of a 2-tap FIR using packed Q15 storage.
    @ Each word in samples[]/coeffs[] is [T | B] = [tap_n+1 | tap_n].
    ldr     r3, =samples
    ldr     r4, =coeffs
    movs    r0, #0              @ accumulator (Q30)
    ldr     r1, [r3], #4        @ r1 = [s1 | s0]
    ldr     r2, [r4], #4        @ r2 = [c1 | c0]
    smlabb  r0, r1, r2, r0      @ r0 += s0*c0  (bottom × bottom)
    smlatt  r0, r1, r2, r0      @ r0 += s1*c1  (top    × top)
loop:
    b   loop

    .align  2
samples: .word 0x00030002
coeffs:  .word 0x00050004
```

**Walkthrough:**

1. One `LDR` brings two samples; one `LDR` brings two coefficients. That's two taps for two memory accesses.
2. `SMLABB` consumes the bottom halves (`s0=2`, `c0=4` → `r0 += 8`); `SMLATT` consumes the top halves (`s1=3`, `c1=5` → `r0 += 15`). Final `r0 = 23`.
3. A naive `MUL`/`ADD` pair with `SXTH` sign-extends would need ~8 instructions for the same two taps — `SMLABB`+`SMLATT` does it in two.

## See also

- [SMLABT](SMLABT.md) — halfword MAC variant (BT)
- [SMLATB](SMLATB.md) — halfword MAC variant (TB)
- [SMLATT](SMLATT.md) — halfword MAC variant (TT)
- [SMLAWB](SMLAWB.md) — halfword MAC variant (WB)
- [SMLAWT](SMLAWT.md) — halfword MAC variant (WT)
- [SMULBB](SMULBB.md) — same product without accumulator
- [SMLAL](SMLAL.md) — 64-bit signed multiply-accumulate (full 32×32)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLABB*.
