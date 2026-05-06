# REV16 — reverse byte order within each halfword of a 32-bit register

## Class & availability

- **Class:** Bit manipulation
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
REV16{<cond>} <Rd>, <Rm>
```

Swaps bytes inside each 16-bit halfword of `<Rm>` independently, leaving the halfwords in their original positions. Use it when you've loaded **two** big-endian 16-bit values packed in one word and need both swapped.

**When you'd actually use this** — you've done a 32-bit load that happens to span two adjacent 16-bit big-endian fields: a pair of audio samples coming back from an I²S codec word, two ADC channel readings packed by a DMA in halfword pairs, or two consecutive 16-bit register fields from a sensor. `REV16` byte-swaps each lane in one cycle without mixing them; `REV` would have wrongly merged the two halfwords together.

## Operands

| Field  | Type        | Constraints                                       |
|--------|-------------|---------------------------------------------------|
| `<Rd>` | destination | R0–R7 (T1) or R0–R12, LR (T2). Not SP, not PC.    |
| `<Rm>` | source      | Same constraint as `<Rd>` for the chosen encoding. |

## Operation (pseudocode)

```text
if ConditionPassed() then
    Rd<31:24> = Rm<23:16>;
    Rd<23:16> = Rm<31:24>;
    Rd<15:8>  = Rm<7:0>;
    Rd<7:0>   = Rm<15:8>;
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width  | Form                                   | Notes                              |
|---------|--------|----------------------------------------|------------------------------------|
| T1      | 16-bit | `1011 1010 01 Rm Rd`                   | Low registers (R0–R7) only.        |
| T2      | 32-bit | `11111010 1001 Rm 1111 Rd 1001 Rm`     | Full register range.               |

## Exceptions / faults

- (none)

## Example

### Example 1 — swap a packed pair of big-endian samples

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ REV16 demo: two big-endian 16-bit samples packed into one 32-bit word.
    @ Source word as bytes:  0x12 0x34 | 0xAB 0xCD
    @ We want each halfword byte-swapped to native LE.
    ldr     r0, =0x1234ABCD
    rev16   r1, r0               @ r1 = 0x3412CDAB
    @ Halfword[1] of r1 = 0x3412 (was 0x1234)
    @ Halfword[0] of r1 = 0xCDAB (was 0xABCD)

    @ Compare: REV would have produced 0xCDAB3412 (whole-word swap).
    rev     r2, r0               @ r2 = 0xCDAB3412
loop:
    b   loop
```

**Walkthrough:**

1. `ldr r0, =0x1234ABCD` — represents two 16-bit big-endian samples (`0x1234` and `0xABCD`) packed together, e.g. read in pairs from an audio peripheral.
2. `rev16 r1, r0` — swaps bytes inside each halfword: `0x1234 → 0x3412` and `0xABCD → 0xCDAB`. The halfwords stay in their lanes.
3. `rev r2, r0` — for contrast: full-word swap mixes the two halfwords together. That's not what you want when each halfword is an independent value.

This is the part that bites people: pick `REV16` (per-halfword) vs `REV` (whole-word) based on **what the bytes mean**, not just where the swap "should" happen.

### Example 2 — byte-swap a single big-endian halfword and zero-extend

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ A device returns an unsigned 16-bit value MSB-first. We loaded it
    @ as a halfword (so it sits in r0[15:0] byte-swapped) and we want
    @ a clean native u16 in r2.
    ldr     r0, =0x00001234      @ raw halfword as read (high byte = 0x12, low = 0x34)
    rev16   r1, r0               @ r1 low halfword now byte-swapped: 0x3412
    uxth    r2, r1               @ r2 = 0x00003412 — clean native u16
loop:
    b   loop
```

**Walkthrough:**

1. `rev16 r1, r0` — swaps the bytes inside the low halfword (`0x1234 → 0x3412`); the high halfword is also swapped but it's zero so we ignore it.
2. `uxth r2, r1` — masks `r1` to its low 16 bits, giving a tidy native u16. If you also wanted *signed* big-endian-to-native, [`REVSH`](REVSH.md) does the swap and sign-extension as one instruction; here we wanted unsigned, so `REV16` + `UXTH` is the right pairing.

## See also

- [REV](REV.md) — full 32-bit byte reversal.
- [REVSH](REVSH.md) — byte-swap the low halfword and sign-extend.
- [UXTH](UXTH.md) / [SXTH](SXTH.md) — extract a single halfword (often used after `REV16`).

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.124 — *REV16*.
