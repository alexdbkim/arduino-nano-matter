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

## See also

- [USAT](USAT.md) — scalar unsigned saturate (with optional pre-shift)
- [SSAT16](SSAT16.md) — signed packed-halfword saturate (DSP)
- [UQADD16](UQADD16.md) / [UQSUB16](UQSUB16.md) — unsigned saturating SIMD add/subtract
- [UXTB16](UXTB16.md) — extract two bytes into two halfword lanes

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.x — *USAT16*.
