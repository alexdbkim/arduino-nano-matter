# USAT — unsigned saturate a 32-bit value to N bits

## Class & availability

- **Class:** Saturation
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
USAT{<c>}{<q>} <Rd>, #<imm>, <Rn>{, <shift>}
```

`<shift>` is optional, one of `LSL #0..31` or `ASR #1..32`. It is applied to `<Rn>` *before* saturation. The source is treated as a *signed* value; the result is clamped into `0 … 2^imm − 1`, so any negative input becomes 0.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR |
| `#<imm>` | saturation width in bits | 0–31 (note: 0 means "saturate to {0}") |
| `<Rn>` | source register | R0–R12, LR |
| `<shift>` | optional pre-shift | `LSL #0..31` or `ASR #1..32` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    operand       = Shift(R[n], shift_t, shift_n, APSR.C)
    (result, sat) = UnsignedSatQ(SInt(operand), imm)   // signed → unsigned clip
    R[d] = ZeroExtend(result, 32)
    if sat then APSR.Q = '1'
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | ✓ |

`Q` is set when clipping occurred (input was negative or larger than `2^imm − 1`). **Q is sticky** — only `MSR APSR_nzcvq, Rn` (writing 0 to bit 27) clears it.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `USAT <Rd>, #<imm0..31>, <Rn>{, LSL #<0..31>}` |
| T1 | 32-bit | `USAT <Rd>, #<imm0..31>, <Rn>, ASR #<1..32>` |

No 16-bit Thumb encoding.

## Exceptions / faults

- (none).

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Clip a signed sample into an unsigned 12-bit DAC range [0, 4095].
    ldr     r0, =5000
    usat    r1, #12, r0         @ r1 = 4095 (0xFFF), APSR.Q = 1
    ldr     r0, =-30
    usat    r2, #12, r0         @ r2 = 0,  APSR.Q stays 1

    @ Convert a Q1.30 value to an unsigned 8-bit pixel intensity.
    ldr     r0, =0x40000000     @ +1.0 in Q1.30
    usat    r3, #8, r0, asr #22 @ shift to Q1.8, then clip to [0,255] → 255
loop:
    b   loop
```

**Walkthrough:**

1. `usat r1, #12, r0` — 5000 is above the 12-bit unsigned ceiling (4095), so `r1` becomes 4095 and `APSR.Q` is set.
2. `usat r2, #12, r0` (with -30) — negative inputs clip to 0. The bit that catches people: `USAT` interprets the source as *signed*, so any negative number floors to 0 even though the output is unsigned.
3. `usat r3, #8, r0, asr #22` — pre-shifts the Q1.30 fixed-point value down 22 places (now Q1.8), then clips into `[0, 255]`. Pre-shift then clip is the standard pattern for converting fixed-point DSP samples to a display/DAC byte.

## See also

- [SSAT](SSAT.md) — signed counterpart (clamps to `−2^(N−1) … 2^(N−1)−1`)
- [USAT16](USAT16.md) — saturate two packed halfwords in parallel (DSP)
- [UQADD8](UQADD8.md) / [UQSUB8](UQSUB8.md) — unsigned saturating SIMD arithmetic
- [MRS](MRS.md) / [MSR](MSR.md) — read/clear the sticky `Q` bit

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.x — *USAT*.
