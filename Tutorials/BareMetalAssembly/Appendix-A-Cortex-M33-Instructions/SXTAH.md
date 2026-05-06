# SXTAH — sign-extend halfword from Rm and add to Rn

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SXTAH  <Rd>, <Rn>, <Rm>{, ROR #<amount>}
```

**When you'd actually use this** is the bread-and-butter "widen a signed Q15 sample to Q31 while accumulating into a running sum" step you find in every audio mean / DC-removal / RMS pre-stage. One `SXTAH` replaces `SXTH tmp, x` + `ADD acc, acc, tmp` and avoids the scratch register; the `ROR #16` form lets you grab the top halfword without a separate shift, exactly what you want when samples arrive packed two per word.

Take the bottom halfword of `Rm` (after an optional rotate), sign-extend to 32 bits, add to `Rn`. The halfword equivalent of `SXTAB`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR |
| `<Rn>` | accumulator input | R0–R12, LR; `Rn = PC` is `SXTH` |
| `<Rm>` | source for halfword to extract | R0–R12, LR |
| `<amount>` | rotation before extraction | 0, 8, 16, or 24 (default 0) |

`ROR #16` selects the top halfword of `Rm`; `ROR #0` selects the bottom one. (`ROR #8` and `#24` are legal but rarely useful here — they'd extract a misaligned halfword.)

## Operation (pseudocode)

```text
if ConditionPassed() then
    rotated = ROR(Rm, amount)
    Rd = Rn + SignExtend(rotated<15:0>, 32)
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates APSR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1111 1010 0000 Rn 1111 Rd 10 rot Rm` (`Rn != 1111`) |

`Rn = 0b1111` becomes `SXTH`. 32-bit only.

## Exceptions / faults

- (none)

## Example

### Example 1 — adding two packed Q15 samples into a Q31 sum

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SXTAH demo: sum two signed 16-bit samples packed in one word
    ldr     r0, =0x80017FFF     @ top half = 0x8001 = -32767, low half = 0x7FFF = +32767
    movs    r1, #0              @ accumulator
    sxtah   r1, r1, r0          @ r1 += sign-ext(0x7FFF) =  +32767 → r1 = 0x00007FFF
    sxtah   r1, r1, r0, ror #16 @ r1 += sign-ext(0x8001) =  -32767 → r1 = 0x00000000
loop:
    b   loop
```

**Walkthrough:**

1. `movs r1, #0` — clear the 32-bit accumulator.
2. First `sxtah` — bottom halfword of `r0` (`0x7FFF`) is sign-extended to `0x00007FFF` and added to `r1`.
3. Second `sxtah ..., ror #16` — `r0` is rotated so its top half lands in bits [15:0], that halfword (`0x8001` = -32767) is sign-extended to `0xFFFF8001` and added. Net result: 0.

This is the bread-and-butter "widen a Q15 sample to Q31 while accumulating" pattern in audio code.

### Example 2 — Q15 sample stream into a Q31 running mean accumulator

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Walk a buffer of N signed Q15 audio samples, accumulating into a
    @ Q31 running sum. Divide by N afterwards to get the Q15 mean
    @ (handy for DC-offset / bias removal in a microphone front-end).
    ldr     r0, =sample_data
    movs    r1, #4               @ N samples
    movs    r2, #0               @ Q31 accumulator
1:
    ldrh    r3, [r0], #2         @ next packed Q15 sample (zero-extended by LDRH)
    sxtah   r2, r2, r3           @ ... but treat low halfword as signed and accumulate
    subs    r1, r1, #1
    bne     1b
loop:
    b   loop

    .balign 2
sample_data:
    .hword 0x7FFF, 0x8001, 0x4000, 0xC000   @ +32767, -32767, +16384, -16384 → sum = 0
```

**Walkthrough:**

1. `ldrh` zero-extends, so a naïve `ADD r2, r2, r3` would treat `0x8001` as +32769 instead of −32767 — a textbook silent sign bug.
2. `sxtah r2, r2, r3` sign-extends the bottom halfword of `r3` to 32 bits and accumulates in one cycle; the running sum stays correct in Q31.
3. After four samples `r2 = 0`, exactly the Q31 mean × N you'd expect for a balanced waveform. To target the *top* halfword of a packed pair instead, swap in `sxtah r2, r2, r3, ror #16` — no separate shift, no scratch register.

## See also

- [SXTAB](SXTAB.md) — byte form
- [UXTAH](UXTAH.md) — zero-extending counterpart
- [SXTH](SXTH.md) — extend without the add
- [SMLAD](SMLAD.md) — pair-wise multiply-accumulate over packed halfwords

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SXTAH*.
