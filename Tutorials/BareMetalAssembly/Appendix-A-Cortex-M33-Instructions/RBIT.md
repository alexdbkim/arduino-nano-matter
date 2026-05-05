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

## See also

- [CLZ](CLZ.md) — combine with `RBIT` to count trailing zeros.
- [REV](REV.md) — byte-level reverse (endianness), not bit-level.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.121 — *RBIT*.
