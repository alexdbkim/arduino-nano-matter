# RBIT — reverse the bit order of a 32-bit word

## Class & availability

- **Class:** Bit manipulation
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
RBIT{<cond>} <Rd>, <Rm>
```

Bit *i* of `<Rd>` becomes bit *31 − i* of `<Rm>`. The byte order is unchanged in the architectural sense — this is a true bit-level mirror of the whole word.

**When you'd actually use this** — three places: the bit-reversal permutation step in an FFT (the textbook reason it exists), CRC and gray-code conversion routines that need bit-reflected lookup tables, and — the trick that gets compilers to ship one-instruction CTZ — `CLZ(RBIT(x))` to count trailing zeros. ARMv7-M / ARMv8-M has no dedicated `CTZ`, so `RBIT` followed by `CLZ` *is* the canonical idiom for "find lowest set bit." Doing the same in plain C usually expands to a 5-or-more-instruction de Bruijn sequence; here it's two cycles.

## Operands

| Field  | Type        | Constraints                  |
|--------|-------------|------------------------------|
| `<Rd>` | destination | R0–R12, LR. Not SP, not PC.  |
| `<Rm>` | source      | R0–R12, LR. Not SP, not PC.  |

## Operation (pseudocode)

```text
if ConditionPassed() then
    for i in 0..31:
        Rd<i> = Rm<31 - i>;
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width  | Form                                   |
|---------|--------|----------------------------------------|
| T1      | 32-bit | `11111010 1001 Rm 1111 Rd 1010 Rm`     |

No 16-bit encoding.

## Exceptions / faults

- (none)

## Example

### Example 1 — count trailing zeros via RBIT + CLZ

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ RBIT demo: count trailing zeros of x by combining RBIT + CLZ.
    ldr     r0, =0x12345678
    rbit    r1, r0               @ r1 = 0x1E6A2C48 (whole-word bit reverse)

    @ ctz(x) = clz(rbit(x)). Useful for "find lowest set bit".
    ldr     r2, =0x00000080      @ only bit 7 set
    rbit    r3, r2               @ moves bit 7 to bit 24
    clz     r4, r3               @ r4 = 7  -> ctz(0x80) = 7
loop:
    b   loop
```

**Walkthrough:**

1. `rbit r1, r0` — mirrors the bits of `r0` end-to-end. Bit 0 of `r0` ends up at bit 31 of `r1`, bit 1 at bit 30, and so on.
2. The classic trick: **count trailing zeros = CLZ(RBIT(x))**. ARM has no dedicated `CTZ`, so `RBIT`+`CLZ` is the canonical idiom and runs in two cycles.
3. `clz r4, r3` after the `rbit` recovers the index of the lowest set bit of the original `r2` — here, 7.

`RBIT` is also handy for protocols that send LSB-first over a wire when your buffer is MSB-first.

### Example 2 — reflect a single byte for a CRC routine

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Many CRC variants (CRC-32, CRC-16/CCITT-reflected, ...) want
    @ each input byte bit-reversed. RBIT mirrors a 32-bit word, so to
    @ reflect just a byte we RBIT then shift the result back down.
    movs    r0, #0xB2            @ input byte: 1011 0010
    rbit    r1, r0               @ r1 = 0100 1101 0000 ... 0000 (byte sits at the top)
    lsr     r1, r1, #24          @ r1 = 0x4D = 0100 1101 (the reflected byte)
loop:
    b   loop
```

**Walkthrough:**

1. `rbit r1, r0` — mirrors all 32 bits. Because `r0` only had bits in positions 0..7, the reflected bits land in positions 24..31.
2. `lsr r1, r1, #24` — slides them back into the low byte. Result: `0xB2` (`1011 0010`) becomes `0x4D` (`0100 1101`), exactly what a reflected-input CRC table expects. Two instructions, no lookup table, no per-bit loop — *this is the trick that gets compilers to emit one-cycle CTZ and one-shot byte reflection on Cortex-M*.

## See also

- [CLZ](CLZ.md) — combine with `RBIT` to count trailing zeros.
- [REV](REV.md) — byte-level reverse (endianness), not bit-level.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.121 — *RBIT*.
