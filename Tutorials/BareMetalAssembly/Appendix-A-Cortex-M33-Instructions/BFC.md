# BFC — clear a contiguous bit field in a register to zero

## Class & availability

- **Class:** Bit manipulation
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
BFC{<cond>} <Rd>, #<lsb>, #<width>
```

Clears `<width>` consecutive bits of `<Rd>` starting at bit position `<lsb>`. Other bits are untouched.

## Operands

| Field    | Type                  | Constraints                                       |
|----------|-----------------------|---------------------------------------------------|
| `<Rd>`   | source & destination  | R0–R12, LR. Not SP, not PC.                       |
| `<lsb>`  | immediate             | 0–31. Position of the least-significant cleared bit. |
| `<width>`| immediate             | 1–(32 − `<lsb>`). Number of bits to clear.        |

## Operation (pseudocode)

```text
if ConditionPassed() then
    msbit = lsb + width - 1;       // 0 ≤ lsb ≤ msbit ≤ 31
    Rd<msbit:lsb> = Zeros(width);
    // all other bits of Rd preserved
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

`BFC` never updates flags.

## Encodings

| Variant | Width  | Form                                              |
|---------|--------|---------------------------------------------------|
| T1      | 32-bit | `11110(0)11011011110(imm3)Rd(imm2)(0)msb` (Thumb-2) |

No 16-bit encoding exists.

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
    @ BFC demo: clear bits [11:4] of a status word, leaving the rest alone.
    ldr     r0, =0xDEADBEEF      @ r0 = 1101 1110 1010 1101 1011 1110 1110 1111
    bfc     r0, #4, #8           @ clear 8 bits starting at bit 4
    @ r0 is now 0xDEAD_B00F
    movs    r1, #0xFF
    bfc     r1, #0, #4           @ clear low nibble: r1 = 0xF0
loop:
    b   loop
```

**Walkthrough:**

1. `ldr r0, =0xDEADBEEF` — loads a known pattern so we can see exactly which bits get cleared.
2. `bfc r0, #4, #8` — zeroes bits 11..4 of `r0`. Bits 31..12 and bits 3..0 are preserved, so `0xDEADBEEF` becomes `0xDEADB00F`.
3. `bfc r1, #0, #4` — zeroes the low 4 bits of `r1`. Handy for aligning a value down to a 16-byte boundary without loading a mask.

This is the part that bites people: `<width>` is a *count*, not a top bit. `bfc r0, #4, #8` clears bits 4 through **11**, not 4 through 8.

## See also

- [BFI](BFI.md) — same operand shape, but inserts bits from another register instead of clearing.
- [UBFX](UBFX.md) — extracts a bit field rather than clearing one.
- [SBFX](SBFX.md) — signed bit-field extract.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.18 — *BFC*.
