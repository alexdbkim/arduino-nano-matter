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

**When you'd actually use this** is the unsigned counterpart of `SXTAH`: a running 32-bit sum of *unsigned* halfwords — typical sources are 12-/16-bit ADC samples, unsigned audio levels, or per-row pixel sums. One `UXTAH` replaces `UXTH tmp, x` + `ADD acc, acc, tmp`, and the `ROR #16` form lets you grab the top halfword of a packed pair with no separate shift. Use it any time you're tempted to write `LDRH` + `ADD` in a tight loop and the source halfword can't be negative.

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

### Example 1 — summing two packed unsigned halfwords

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

### Example 2 — sliding-window sum of an unsigned ADC stream

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Walk a buffer of unsigned 16-bit ADC samples (e.g. 12-bit ADC
    @ readings zero-extended) and build a window sum. Divide by N
    @ afterwards for the mean.
    ldr     r0, =adc_buf
    movs    r1, #4               @ window length
    movs    r2, #0               @ running unsigned sum
1:
    ldrh    r3, [r0], #2         @ next 16-bit sample (zero-extended by LDRH)
    uxtah   r2, r2, r3           @ accumulate as unsigned halfword
    subs    r1, r1, #1
    bne     1b
loop:
    b   loop

    .balign 2
adc_buf:
    .hword 0x0FFF, 0x0800, 0x0AAA, 0x0123    @ 4095 + 2048 + 2730 + 291 = 9164
```

**Walkthrough:**

1. `LDRH` already zero-extends so a plain `ADD` would also work here — what `UXTAH` buys you is the `ROR #16` form when samples arrive packed two-per-word, and stylistic intent ("treat this halfword as unsigned, no funny business").
2. After the loop `r2 = 9164`, ready to be divided by 4 to get the unsigned mean. No risk of sign-extension surprises.
3. Swap to `SXTAH` the moment any sample can be negative (e.g. signed sensor data) — it's the same shape but the right answer.

## See also

- [SXTAH](SXTAH.md) — signed counterpart
- [UXTAB](UXTAB.md) — byte form
- [UXTH](UXTH.md) — extend without the add
- [UADD16](UADD16.md) — pair-wise unsigned halfword add

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *UXTAH*.
