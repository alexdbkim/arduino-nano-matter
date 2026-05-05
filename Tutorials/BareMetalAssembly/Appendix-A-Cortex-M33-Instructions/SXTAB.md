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

## See also

- [SXTAB16](SXTAB16.md) — SIMD form, two bytes at once
- [SXTAH](SXTAH.md) — same idea, halfword
- [UXTAB](UXTAB.md) — zero-extending counterpart
- [SXTB](SXTB.md) — extend without the add

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SXTAB*.
