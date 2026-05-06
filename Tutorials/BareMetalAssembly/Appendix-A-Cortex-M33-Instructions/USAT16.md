# USAT16 — unsigned saturate two packed halfwords in parallel

## Class & availability

- **Class:** Saturation (DSP-SIMD)
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
USAT16{<c>}{<q>} <Rd>, #<imm>, <Rn>
```

Treats `<Rn>` as two packed signed 16-bit halfwords; clips each independently into `0 … 2^imm − 1` and zero-extends each back into a 16-bit lane of `<Rd>`. No pre-shift operand.

**When you'd actually use this**: at the tail of a SIMD image/audio pipeline, converting two signed accumulators (held as `int16|int16` in one register) into two unsigned 8-bit channel values for a framebuffer, or two 10-bit DAC samples — in one cycle. Two scalar `USAT`s would also work, but `USAT16` is half the cost. The double clip per lane (negatives floor to `0`, overflows clamp to `2^N − 1`) is exactly the "no wrap-around" behaviour you need so a transient negative excursion in lane A doesn't become a bright artefact in your image. The shared sticky `Q` flag is "did either lane saturate?" — read with `MRS r?, APSR`, no per-lane info, cleared only via `MSR APSR_nzcvq`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR |
| `#<imm>` | saturation width in bits | 0–15 |
| `<Rn>` | source register | R0–R12, LR (two packed `int16`) |

## Operation (pseudocode)

```text
if ConditionPassed() then
    (lo, sat1) = UnsignedSatQ(SInt(R[n]<15:0>),  imm)
    (hi, sat2) = UnsignedSatQ(SInt(R[n]<31:16>), imm)
    R[d]<15:0>  = ZeroExtend(lo, 16)
    R[d]<31:16> = ZeroExtend(hi, 16)
    if sat1 || sat2 then APSR.Q = '1'
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | ✓ |

`Q` is set if either lane clipped. **Q is sticky**; clear with `MSR APSR_nzcvq, Rn` (bit 27 = 0).

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `USAT16 <Rd>, #<imm0..15>, <Rn>` |

DSP-extension; 32-bit Thumb only.

## Exceptions / faults

- (none).

## Example

### Example 1 — pack two pixels

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Pack of two signed samples → two 8-bit pixel intensities.
    ldr     r0, =0x01F4FF38     @ hi = +500, lo = -200
    usat16  r1, #8, r0          @ hi → 0x00FF (255), lo → 0x0000; APSR.Q = 1

    @ Different mix: one in range, one above.
    ldr     r0, =0x00640190     @ hi = +100, lo = +400
    usat16  r2, #8, r0          @ hi → 100, lo → 255; APSR.Q stays 1
loop:
    b   loop
```

**Walkthrough:**

1. `usat16 r1, #8, r0` — both halfwords are interpreted as *signed* int16. The high lane `+500` clips down to `255`; the low lane `-200` (negative) floors to `0`. Negative-floor-to-zero is the gotcha — `USAT16` is the unsigned clip of a *signed* input, exactly like the scalar `USAT`.
2. `usat16 r2, #8, r0` — `+100` passes through untouched (still `100`); `+400` clips to `255`. `Q` is sticky and remains `1` from the previous instruction. Two pixels processed in one cycle is why DSP-SIMD exists.

### Example 2 — two channels to a 10-bit DAC

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Two channel accumulators packed as int16|int16 → two unsigned 10-bit DAC samples.
    ldr     r0, =0x0500FFE0     @ hi = +1280, lo = -32 (signed)
    usat16  r1, #10, r0         @ hi → 1023 (clip), lo → 0 (negative floors), Q=1

    @ Both lanes in range — but Q stays sticky from before.
    ldr     r0, =0x01000200     @ hi = +256, lo = +512
    usat16  r2, #10, r0         @ hi → 256, lo → 512, lanes pass through

    @ Both lanes above the ceiling — both clamp.
    ldr     r0, =0x07FF0FFF     @ hi = +2047, lo = +4095
    usat16  r3, #10, r0         @ both → 1023; Q remains 1 (still sticky)

    @ Drain Q in the usual way.
    mrs     r4, apsr
    bic     r4, r4, #(1 << 27)
    msr     APSR_nzcvq, r4
loop:
    b   loop
```

**Walkthrough:**

1. First `usat16` — illustrates the asymmetric clip per lane: the high lane saturates at the upper rail, the low lane (a small negative ADC offset) floors to `0`. In a stereo DAC pipeline this stops a one-sample noise spike from producing a click on the *other* channel — each lane is independent.
2. Second `usat16` — clean values; both lanes pass through unchanged. `Q` is sticky and still set from the first instruction. You cannot use `Q` as "did *this* op clip?" — only as "did anything since the last `MSR APSR_nzcvq` clip?".
3. Third `usat16` — both lanes overflow. The result is correct (both `1023`), but `Q` looks identical to the case where only one lane clipped. If you need per-lane diagnostics, do them with `SXTH`/`UXTH` and `CMP` before the `USAT16`.
4. `MRS … BIC #(1<<27) … MSR APSR_nzcvq` — the *only* path to clear Q. There is no `Bxx`-on-Q in Thumb.

## See also

- [USAT](USAT.md) — scalar unsigned saturate (with optional pre-shift)
- [SSAT16](SSAT16.md) — signed packed-halfword saturate (DSP)
- [UQADD16](UQADD16.md) / [UQSUB16](UQSUB16.md) — unsigned saturating SIMD add/subtract
- [UXTB16](UXTB16.md) — extract two bytes into two halfword lanes

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.x — *USAT16*.
