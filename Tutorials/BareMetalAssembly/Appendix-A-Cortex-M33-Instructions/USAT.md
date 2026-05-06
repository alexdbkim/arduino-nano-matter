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

**When you'd actually use this**: clamping a signed DSP accumulator into an unsigned hardware range — `0..255` for an 8-bit pixel after image blending, `0..1023` for a 10-bit PWM duty-cycle, `0..4095` for a 12-bit DAC. Two clips happen at once: any negative input floors to 0, anything above `2^N − 1` saturates to the max. That "negative floors to zero" behaviour is exactly what you want when a filter under-shoots a black pixel — a wrap with plain truncation would produce a bright pixel out of nowhere; without `USAT`, you'd write `cmp #0; movlt #0; cmp #N; movgt #N` for every output. The sticky `Q` flag tells you the rail was hit; visible only via `MRS r?, APSR` bit 27, cleared only via `MSR APSR_nzcvq`, never by a `Bxx`.

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

### Example 1 — clip a sample to 12-bit DAC range

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

### Example 2 — ADC value to a 10-bit PWM duty cycle

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Pretend r0 holds a "cooked" ADC value (signed int32, possibly out of range)
    @ and we want to drive a 10-bit PWM peripheral whose duty register is [0,1023].
    ldr     r0, =1500           @ above the 10-bit ceiling
    usat    r1, #10, r0         @ r1 = 1023, Q=1

    ldr     r0, =-7             @ negative — slight ADC offset error
    usat    r2, #10, r0         @ r2 = 0 (negative floors to 0)

    ldr     r0, =500            @ in-range value
    usat    r3, #10, r0         @ r3 = 500 (passes through)

    @ Same idea but with an ASR pre-shift: Q15 fraction → 10-bit duty.
    ldr     r0, =0x6000         @ ≈ 0.75 in Q15
    usat    r4, #10, r0, asr #5 @ shift down 5 → 0x300 (768), fits, no clip

    @ Read the sticky Q to find out whether the controller has been railing.
    mrs     r5, apsr
    bic     r5, r5, #(1 << 27)
    msr     APSR_nzcvq, r5
loop:
    b   loop
```

**Walkthrough:**

1. `usat r1, #10, r0` — `1500` is above `1023`, the maximum 10-bit unsigned value. The result clamps at `1023`; `Q` latches.
2. `usat r2, #10, r0` — input is `−7`. `USAT` reads it as a signed quantity, sees it is below `0`, and floors to `0`. This is the gotcha: an unsigned destination but a *signed* source interpretation. Crucial for PWM: a slightly-negative ADC reading cannot become a runaway duty cycle; it just becomes "off".
3. `usat r3, #10, r0` — clean middle-of-range value, no clip. `Q` is still latched from above; `USAT` doesn't unset it on a non-saturating op.
4. `usat r4, #10, r0, asr #5` — ASR pre-shift converts the Q15 fraction to a Q10 duty count in the same instruction. Doing it as `ASR #5; USAT` separately gives a window where the unshifted value could be above `1023` while the shifted one isn't, so you'd have to think harder about which to clamp.
5. `mrs … bic #(1<<27) … msr APSR_nzcvq` — only way to clear Q. No conditional branch tests it.

## See also

- [SSAT](SSAT.md) — signed counterpart (clamps to `−2^(N−1) … 2^(N−1)−1`)
- [USAT16](USAT16.md) — saturate two packed halfwords in parallel (DSP)
- [UQADD8](UQADD8.md) / [UQSUB8](UQSUB8.md) — unsigned saturating SIMD arithmetic
- [MRS](MRS.md) / [MSR](MSR.md) — read/clear the sticky `Q` bit

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.x — *USAT*.
