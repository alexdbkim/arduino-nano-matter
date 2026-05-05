# UXTAH — zero-extend halfword from Rm and add to Rn

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UXTAH  <Rd>, <Rn>, <Rm>{, ROR #<amount>}
```

Take the bottom halfword of `Rm` (after an optional rotate), zero-extend to 32 bits, add to `Rn`. The unsigned cousin of `SXTAH`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR |
| `<Rn>` | accumulator input | R0–R12, LR; `Rn = PC` is `UXTH` |
| `<Rm>` | source for halfword to extract | R0–R12, LR |
| `<amount>` | rotation before extraction | 0, 8, 16, or 24 (default 0) |

`ROR #16` selects the top halfword. `ROR #8` / `#24` produce misaligned halfwords — legal, almost never what you want.

## Operation (pseudocode)

```text
if ConditionPassed() then
    rotated = ROR(Rm, amount)
    Rd = Rn + ZeroExtend(rotated<15:0>, 32)
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates APSR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1111 1010 0001 Rn 1111 Rd 10 rot Rm` (`Rn != 1111`) |

`Rn = 0b1111` becomes `UXTH`. 32-bit only.

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
    @ UXTAH demo: sum two unsigned 16-bit ADC samples packed in one word
    ldr     r0, =0xC0001234     @ top half = 0xC000 (49152), low half = 0x1234 (4660)
    movs    r1, #0              @ accumulator
    uxtah   r1, r1, r0          @ r1 += 0x1234        →  4660
    uxtah   r1, r1, r0, ror #16 @ r1 += 0xC000        → 53812
loop:
    b   loop
```

**Walkthrough:**

1. `movs r1, #0` — clear the 32-bit accumulator.
2. First `uxtah` — bottom halfword of `r0` (`0x1234` = 4660) is zero-extended and added to `r1`.
3. Second `uxtah ..., ror #16` — rotates `r0` so its top half lands in [15:0], adds `0xC000` = 49152. Final `r1` = 53812. No sign nonsense, no overflow until the running total exceeds 2^32.

Use this for unsigned ADC, RGB component summing, or any halfword stream where values are guaranteed non-negative.

## See also

- [SXTAH](SXTAH.md) — signed counterpart
- [UXTAB](UXTAB.md) — byte form
- [UXTH](UXTH.md) — extend without the add
- [UADD16](UADD16.md) — pair-wise unsigned halfword add

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *UXTAH*.
