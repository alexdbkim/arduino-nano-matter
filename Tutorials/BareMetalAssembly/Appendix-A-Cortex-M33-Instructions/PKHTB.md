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

## See also

- [PKHBT](PKHBT.md) — mirror form
- [SSAT](SSAT.md) — saturate to a narrower width before packing
- [SXTH](SXTH.md) — sign-extend a halfword

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *PKHBT, PKHTB*.
