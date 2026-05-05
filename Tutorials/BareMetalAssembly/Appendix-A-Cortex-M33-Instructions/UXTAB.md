# UXTAB — zero-extend byte from Rm and add to Rn

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UXTAB  <Rd>, <Rn>, <Rm>{, ROR #<amount>}
```

Same shape as `SXTAB`, but the extracted byte is zero-extended (treated as unsigned). Use when bytes represent magnitudes, pixel intensities, or unsigned counts — never for signed sample data.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR |
| `<Rn>` | accumulator input | R0–R12, LR; `Rn = PC` is `UXTB` |
| `<Rm>` | source for byte to extract | R0–R12, LR |
| `<amount>` | rotation before extraction | 0, 8, 16, or 24 (default 0) |

## Operation (pseudocode)

```text
if ConditionPassed() then
    rotated = ROR(Rm, amount)
    Rd = Rn + ZeroExtend(rotated<7:0>, 32)
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates APSR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1111 1010 0101 Rn 1111 Rd 10 rot Rm` (`Rn != 1111`) |

`Rn = 0b1111` becomes `UXTB`. 32-bit only.

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
    @ UXTAB demo: histogram-style sum of four unsigned bytes packed in a word
    ldr     r0, =0xFF0180A0     @ four unsigned bytes: 0xA0=160, 0x80=128, 0x01=1, 0xFF=255
    movs    r1, #0              @ running total
    uxtab   r1, r1, r0          @ r1 += 0xA0 = 160      → 160
    uxtab   r1, r1, r0, ror #8  @ r1 += 0x80 = 128      → 288
    uxtab   r1, r1, r0, ror #16 @ r1 += 0x01 = 1        → 289
    uxtab   r1, r1, r0, ror #24 @ r1 += 0xFF = 255      → 544
loop:
    b   loop
```

**Walkthrough:**

1. `movs r1, #0` — clear the running total.
2. Each `uxtab` rotates `r0` so a different byte lands in [7:0] and adds it (zero-extended) to `r1`. Final sum 544 = 160+128+1+255.

The whole point: the extracted byte is treated as `0..255`, never negative. Pick `SXTAB` instead the moment your bytes carry a sign.

## See also

- [SXTAB](SXTAB.md) — sign-extending counterpart
- [UXTAB16](UXTAB16.md) — SIMD form, two bytes at once
- [UXTAH](UXTAH.md) — halfword form
- [UXTB](UXTB.md) — extend without the add

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *UXTAB*.
