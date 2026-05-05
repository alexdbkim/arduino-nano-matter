# SSAT — signed saturate a 32-bit value to N bits

## Class & availability

- **Class:** Saturation
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SSAT{<c>}{<q>} <Rd>, #<imm>, <Rn>{, <shift>}
```

`<shift>` is optional and is one of `LSL #0..31` or `ASR #1..32`. It is applied to `<Rn>` *before* saturation — handy for fixed-point Q-format scaling.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR (not PC, not SP) |
| `#<imm>` | saturation width in bits | 1–32 (the result is clamped to the signed range `−2^(imm−1) … 2^(imm−1)−1`) |
| `<Rn>` | source register | R0–R12, LR |
| `<shift>` | optional pre-shift | `LSL #0..31` or `ASR #1..32` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    operand   = Shift(R[n], shift_t, shift_n, APSR.C)   // signed value
    (result, sat) = SignedSatQ(SInt(operand), imm)
    R[d] = SignExtend(result, 32)
    if sat then APSR.Q = '1'    // sticky: never cleared by SSAT itself
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | ✓ |

`Q` is set if and only if the result was clipped. **Q is sticky** — once set it stays set until software clears it with `MSR APSR_nzcvq, Rn` (writing a 0 into bit 27). N/Z/C/V are untouched.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SSAT <Rd>, #<imm1..32>, <Rn>{, LSL #<0..31>}` |
| T1 | 32-bit | `SSAT <Rd>, #<imm1..32>, <Rn>, ASR #<1..32>` |

There is no 16-bit Thumb form.

## Exceptions / faults

- (none) — pure register operation.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Clip a 32-bit signed sample to the range of a 16-bit DAC: [-32768, +32767].
    ldr     r0, =100000         @ way out of range — would wrap if truncated
    ssat    r1, #16, r0         @ r1 =  32767, APSR.Q = 1
    ldr     r0, =-50000
    ssat    r2, #16, r0         @ r2 = -32768, APSR.Q stays 1 (sticky)

    @ Q1.30 -> Q1.15 fixed-point: arithmetic-shift right by 15, then clip.
    ldr     r0, =0x40000000     @ +1.0 in Q1.30
    ssat    r3, #16, r0, asr #15 @ r3 = 0x8000 → saturates to +32767

    @ Read and clear the sticky Q flag.
    mrs     r4, apsr            @ r4 bit 27 = Q
    bic     r4, r4, #(1 << 27)
    msr     APSR_nzcvq, r4      @ Q now 0
loop:
    b   loop
```

**Walkthrough:**

1. `ssat r1, #16, r0` — clamps `r0` into the signed 16-bit range and sign-extends back to 32 bits. Because 100000 > 32767 the result is 32767 and `APSR.Q` becomes 1.
2. `ssat r2, #16, r0` (with -50000) — clamps to -32768; Q is *already* 1 and stays 1, the hardware never clears it.
3. `ssat r3, #16, r0, asr #15` — does `r0 >> 15` first (Q1.30 → Q1.15), then saturates. This is the canonical "convert and clip" pattern for DSP code; the part that bites people is forgetting that the shift happens *before* the clip, so the saturation width applies to the shifted value.
4. `mrs` / `bic` / `msr APSR_nzcvq, r4` — the *only* way to clear Q. `APSR_nzcvq` writes the N, Z, C, V, Q bits of APSR; ordinary arithmetic never clears Q on its own.

## See also

- [USAT](USAT.md) — unsigned counterpart (clamps to `0 … 2^N−1`)
- [SSAT16](SSAT16.md) — saturate two packed halfwords in parallel (DSP)
- [QADD](QADD.md) — saturating add that also sets `Q`
- [MRS](MRS.md) / [MSR](MSR.md) — read/clear the sticky `Q` bit

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.x — *SSAT*.
