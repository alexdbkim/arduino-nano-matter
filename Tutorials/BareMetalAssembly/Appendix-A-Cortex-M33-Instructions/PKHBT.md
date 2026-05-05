# PKHBT — pack halfword: Bottom of Rn, Top of Rm (optionally shifted)

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
PKHBT  <Rd>, <Rn>, <Rm>{, LSL #<imm>}
```

Glues two 16-bit halfwords from two registers into one 32-bit word. The **B**ottom half comes from `Rn`, the **T**op half comes from `Rm` (after an optional left shift of 0–31).

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR |
| `<Rn>` | provides bits [15:0] of result | R0–R12, LR |
| `<Rm>` | provides bits [31:16] of result (after shift) | R0–R12, LR |
| `<imm>` | optional `LSL` amount on `<Rm>` | 0–31 (default 0) |

The shift on `Rm` is useful for aligning a halfword that currently lives in the bottom of a register: `LSL #16` moves it into the top.

## Operation (pseudocode)

```text
if ConditionPassed() then
    operand2 = LSL(Rm, imm)        // imm = 0..31
    Rd<15:0>  = Rn<15:0>
    Rd<31:16> = operand2<31:16>
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates APSR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1110 1010 1100 Rn (imm3) Rd (imm2) 00 Rm` |

`tb = 0` distinguishes `PKHBT` from `PKHTB`. 32-bit only.

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
    @ PKHBT demo: build a stereo audio sample = (right<<16) | left
    ldr     r0, =0x0000AAAA     @ left  channel in low half
    ldr     r1, =0x0000BBBB     @ right channel in low half
    pkhbt   r2, r0, r1, lsl #16 @ r2 = 0xBBBB_AAAA
    @ Compare with the no-shift form:
    ldr     r3, =0x12345678     @ already has wanted top half (0x1234) in its top
    pkhbt   r4, r0, r3          @ r4 = 0x1234_AAAA
loop:
    b   loop
```

**Walkthrough:**

1. `pkhbt r2, r0, r1, lsl #16` — keeps `r0`'s low half (`0xAAAA`) as the result's low half, then takes `r1` shifted left by 16 (so `0xBBBB` lands in the top half) and uses *its* top half. Result: `0xBBBB_AAAA`. Classic "merge two mono samples into stereo".
2. `pkhbt r4, r0, r3` — same idea but `r3` already has the wanted halfword in bits [31:16], so no shift is needed. `r4 = 0x1234_AAAA`.

The mental model: `Rn` always contributes the **bottom** half as-is; `Rm` (post-shift) always contributes its **top** half.

## See also

- [PKHTB](PKHTB.md) — mirror image: top of `Rn`, bottom of `Rm` (optionally `ASR`-shifted)
- [SXTH](SXTH.md) — sign-extend a single halfword
- [UXTH](UXTH.md) — zero-extend a single halfword

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *PKHBT, PKHTB*.
