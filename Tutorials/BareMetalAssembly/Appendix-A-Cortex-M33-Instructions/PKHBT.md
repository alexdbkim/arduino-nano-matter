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

**When you'd actually use this** is the one-instruction "build a packed `[c1|c0]` halfword pair from two scalar registers". It's what you reach for just before feeding a Q15 sample/coefficient pair into `SMLAD`, `SMUAD`, or any other dual-16-bit DSP op that consumes a packed word. Without it you'd need a `LSL` + `ORR` (or `BFI`) sequence that chews an extra register and a cycle. Treat `PKHBT` as "the SIMD packer" the moment two halfwords are scattered across separate registers.

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

### Example 1 — stereo audio sample assembly

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

### Example 2 — building a packed Q15 coefficient pair `[c1|c0]`

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Build a packed Q15 coefficient pair [c1 | c0] ready for SMLAD
    ldr     r0, =0x00002000     @ c0 = 0x2000  (Q15 ≈ 0.25), in low half of r0
    ldr     r1, =0x00006000     @ c1 = 0x6000  (Q15 ≈ 0.75), in low half of r1
    pkhbt   r2, r0, r1, lsl #16 @ r2 = 0x6000_2000 = [c1 | c0]
    @ r2 is now a packed coefficient pair; feed it to SMLAD against
    @ a sample pair packed [s1|s0] and one instruction does
    @ acc += s0*c0 + s1*c1.
loop:
    b   loop
```

**Walkthrough:**

1. `c0` lives in the low half of `r0`; `c1` lives in the low half of `r1`. Each was produced earlier (e.g. by a Q15 quantiser or table lookup).
2. `pkhbt r2, r0, r1, lsl #16` — keeps `r0`'s bottom half (`0x2000`) as the result's bottom half, then shifts `r1` left 16 so `0x6000` sits in its top half, and grafts that on top. Result: `r2 = 0x6000_2000`.
3. `r2` is now in the exact packed-halfword layout `SMLAD`/`SMUAD` expect — no extra `LSL`+`ORR` or scratch register required.

## See also

- [PKHTB](PKHTB.md) — mirror image: top of `Rn`, bottom of `Rm` (optionally `ASR`-shifted)
- [SXTH](SXTH.md) — sign-extend a single halfword
- [UXTH](UXTH.md) — zero-extend a single halfword

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *PKHBT, PKHTB*.
