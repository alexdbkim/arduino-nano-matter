# SXTAB — sign-extend byte from Rm and add to Rn

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SXTAB  <Rd>, <Rn>, <Rm>{, ROR #<amount>}
```

**When you'd actually use this** — any time you're walking a packed byte stream of *signed* samples (8-bit audio deltas, signed accelerometer axes, motion-vector components) and want a running 32-bit total. `SXTAB` collapses the two-instruction `SXTB tmp, src` + `ADD acc, acc, tmp` sequence into one cycle and frees the scratch register. The rotate operand even lets you pick lane 0/1/2/3 of a packed-byte word without a separate shift, so a four-byte signed accumulation becomes four `SXTAB`s with `ROR #0/8/16/24` and no other arithmetic.

Take the bottom byte of `Rm` (after an optional `ROR` of 0/8/16/24 bits), sign-extend it to 32 bits, then add it to `Rn`. One instruction = "extract a signed byte and accumulate it".

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR |
| `<Rn>` | accumulator input | R0–R12, LR; `Rn = PC` is `SXTB` instead |
| `<Rm>` | source for byte to extract | R0–R12, LR |
| `<amount>` | rotation before extraction | 0, 8, 16, or 24 (default 0) |

The rotate lets you pick which byte of `Rm` you want without a separate shift: `ROR #8` selects bits[15:8], `ROR #16` selects bits[23:16], `ROR #24` selects bits[31:24].

## Operation (pseudocode)

```text
if ConditionPassed() then
    rotated = ROR(Rm, amount)       // amount in {0, 8, 16, 24}
    Rd = Rn + SignExtend(rotated<7:0>, 32)
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates APSR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1111 1010 0100 Rn 1111 Rd 10 rot Rm` (`Rn != 1111`) |

When `Rn = 0b1111` the encoding becomes `SXTB`. 32-bit only.

## Exceptions / faults

- (none)

## Example

### Example 1 — four-byte signed-byte running sum via lane rotation

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SXTAB demo: running sum of signed 8-bit ADC samples packed in a word
    ldr     r0, =0x01FE7F80     @ four signed bytes: 0x80=-128, 0x7F=+127, 0xFE=-2, 0x01=+1
    movs    r1, #0              @ accumulator
    sxtab   r1, r1, r0          @ r1 += sign-ext(0x80) = -128 → r1 = -128
    sxtab   r1, r1, r0, ror #8  @ r1 += sign-ext(0x7F) = +127 → r1 = -1
    sxtab   r1, r1, r0, ror #16 @ r1 += sign-ext(0xFE) = -2   → r1 = -3
    sxtab   r1, r1, r0, ror #24 @ r1 += sign-ext(0x01) = +1   → r1 = -2
loop:
    b   loop
```

**Walkthrough:**

1. `movs r1, #0` — clear the accumulator. Forgetting this is the classic "why is my running sum nonsense" bug.
2. Each `sxtab` rotates `r0` so a different byte lands in bits [7:0], sign-extends it to 32 bits, and adds it to `r1`. Without `SXTAB` you'd need `LSL`/`ASR` (or `SXTB` + `ADD`) per byte.

`SXTAB` is the single-byte cousin of `SXTAB16`. Use this for serial byte streams; use `SXTAB16` when two bytes can be processed in parallel.

### Example 2 — accelerometer signed-byte bias accumulator

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Walk a buffer of signed 8-bit accelerometer samples and sum them
    @ into a 32-bit bias-tracker. LDRB returns an unsigned byte, but
    @ SXTAB re-interprets it as signed when adding.
    ldr     r0, =sample_buf     @ pointer to N signed bytes
    movs    r1, #4              @ N = 4 samples
    movs    r2, #0              @ signed running sum
1:
    ldrb    r3, [r0], #1        @ fetch raw byte (zero-extended by LDRB)
    sxtab   r2, r2, r3          @ ... but treat it as signed and accumulate
    subs    r1, r1, #1
    bne     1b
loop:
    b   loop

    .balign 4
sample_buf:
    .byte 0x80, 0x7F, 0xFE, 0x01     @ -128, +127, -2, +1  →  sum = -2
```

**Walkthrough:**

1. `ldrb` always zero-extends, so naïvely `ADD r2, r2, r3` would treat `0x80` as +128 instead of −128 — silent bias bug.
2. `sxtab r2, r2, r3` takes the low byte of `r3`, sign-extends it to 32 bits, and adds in one cycle. No scratch register, correct sign.
3. After four iterations `r2 = -128 + 127 + -2 + 1 = -2`. Replace the `ldrb`/`sxtab` pair with `ldrsb` + `add` and you get the same answer in two instructions instead of two — but `sxtab` shines when the byte is already in a register (e.g. extracted from a packed word with `ROR`).

## See also

- [SXTAB16](SXTAB16.md) — SIMD form, two bytes at once
- [SXTAH](SXTAH.md) — same idea, halfword
- [UXTAB](UXTAB.md) — zero-extending counterpart
- [SXTB](SXTB.md) — extend without the add

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SXTAB*.
