# PKHTB — pack halfword: Top of Rn, Bottom of Rm (optionally ASR-shifted)

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
PKHTB  <Rd>, <Rn>, <Rm>{, ASR #<imm>}
```

**When you'd actually use this** picks up where `PKHBT` leaves off: when the halfword you want for the *bottom* lane already lives in the upper bits of some register — typically because it's the Q31 result of a saturating multiply or a left-aligned accumulator — `PKHTB ..., ASR #16` arithmetic-narrows it back to Q15 *and* drops it under an existing top half in one 32-bit instruction. The scalar alternative is `ASR #16` then `BFI`, two instructions plus a scratch. Reach for `PKHTB` whenever the data flow reads "multiply produced a Q31, now repack it next to another halfword".

Mirror of `PKHBT`. The **T**op half of the result comes from `Rn`; the **B**ottom half comes from `Rm`, optionally arithmetic-shift-right by 1–32 first (handy when `Rm` holds a 32-bit signed value you want to narrow into a halfword).

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR |
| `<Rn>` | provides bits [31:16] of result | R0–R12, LR |
| `<Rm>` | provides bits [15:0] of result (after shift) | R0–R12, LR |
| `<imm>` | optional `ASR` amount on `<Rm>` | 1–32 (`ASR #32` encoded as 0; default = no shift) |

`ASR` (not `LSL`) is the natural shift here because the bottom half is being taken from a value that may have a sign bit higher up — arithmetic shift preserves the sign.

## Operation (pseudocode)

```text
if ConditionPassed() then
    operand2 = ASR(Rm, imm)        // imm = 1..32
    Rd<31:16> = Rn<31:16>
    Rd<15:0>  = operand2<15:0>
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates APSR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1110 1010 1100 Rn (imm3) Rd (imm2) 10 Rm` |

`tb = 1` distinguishes `PKHTB` from `PKHBT`. 32-bit only.

## Exceptions / faults

- (none)

## Example

### Example 1 — packing a halfword + Q31 narrowed bottom

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ PKHTB demo: combine high half of an audio sample with a Q15 coefficient
    ldr     r0, =0xCAFE0000     @ 0xCAFE is the wanted top half
    ldr     r1, =0x12345678     @ low half (0x5678) is the wanted bottom half
    pkhtb   r2, r0, r1          @ r2 = 0xCAFE_5678

    @ With ASR: narrow a Q31 value down to Q15 and pack it under r0's top half
    ldr     r3, =0x40000000     @ Q31 = 0.5
    pkhtb   r4, r0, r3, asr #16 @ r3>>16 = 0x00004000 → low half = 0x4000
                                @ r4 = 0xCAFE_4000
loop:
    b   loop
```

**Walkthrough:**

1. `pkhtb r2, r0, r1` — keeps `r0`'s top half (`0xCAFE`) and grafts `r1`'s low half (`0x5678`) underneath. No shift.
2. `pkhtb r4, r0, r3, asr #16` — first `r3` is sign-shifted right by 16 (a Q31 → Q15 conversion), giving `0x00004000`; its bottom half (`0x4000`) becomes the result's bottom half. Result: `0xCAFE_4000`.

Use `PKHBT` when you want bottom of `Rn` + top of `Rm` (and `LSL` makes sense). Use `PKHTB` when you want top of `Rn` + bottom of `Rm` (and `ASR` makes sense). The shift operator literally tells you which way the data is moving.

### Example 2 — repacking a Q31 multiply result next to a Q15 coefficient

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Imagine: r0's top half holds c1 (Q15), and r1 holds a Q31 product
    @ from an earlier saturating multiply that we now want narrowed to Q15
    @ and packed *under* c1 as a [c1 | sample] pair ready for SMLAD.
    ldr     r0, =0x40000000     @ top half = 0x4000 (c1 = Q15 ≈ 0.5); bottom don't care
    ldr     r1, =0x7FFE0000     @ Q31 product ≈ +1.0 (sign bit clear, top-aligned)
    pkhtb   r2, r0, r1, asr #16 @ r1 >>s 16 = 0x00007FFE → low half = 0x7FFE
                                @ r2 = 0x4000_7FFE = [c1 | sample]
loop:
    b   loop
```

**Walkthrough:**

1. `r0` carries a Q15 coefficient `c1` already left-aligned in bits [31:16]; `r1` carries a Q31 multiplier output that we need to narrow.
2. `pkhtb r2, r0, r1, asr #16` arithmetic-shifts `r1` right by 16 so its sign-preserving Q15 form (`0x7FFE`) lands in the low half, then takes that as the result's bottom half and keeps `r0`'s top half (`0x4000`) on top.
3. Result `r2 = 0x4000_7FFE` — a `[coefficient | sample]` packed word ready for `SMLAD`/`SMLALD`. Without `PKHTB` you'd need `ASR r1, #16` plus `BFI r2, r1, #0, #16`, two instructions and an extra register live across them.

## See also

- [PKHBT](PKHBT.md) — mirror form
- [SSAT](SSAT.md) — saturate to a narrower width before packing
- [SXTH](SXTH.md) — sign-extend a halfword

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *PKHBT, PKHTB*.
