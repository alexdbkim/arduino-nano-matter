# UXTB — zero-extend a byte from a register to 32 bits, with optional rotation

## Class & availability

- **Class:** Bit manipulation
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UXTB{<cond>} <Rd>, <Rm>{, ROR #<rotation>}
```

Optionally rotates `<Rm>` right by 0/8/16/24 bits, takes the bottom 8 bits of the rotated value, and zero-extends to 32 bits in `<Rd>`. The rotation lets you pick any of the four bytes of `<Rm>` without a separate shift.

**When you'd actually use this** — masking a register down to its low byte to use as a 0..255 table index, unpacking individual byte channels of a packed pixel/word using only the rotation field, or normalising a value after an arithmetic op that didn't auto-extend. `UXTB` is the one-instruction, no-literal-pool alternative to `AND r1, r0, #0xFF` and to `LSR + AND` chains for the higher bytes.

## Operands

| Field        | Type        | Constraints                                                |
|--------------|-------------|------------------------------------------------------------|
| `<Rd>`       | destination | R0–R7 (T1) or R0–R12, LR (T2). Not SP, not PC.             |
| `<Rm>`       | source      | Same constraint as `<Rd>` for the chosen encoding.         |
| `<rotation>` | immediate   | One of `0`, `8`, `16`, `24`. Optional; default is `0`. T1 has no rotation. |

## Operation (pseudocode)

```text
if ConditionPassed() then
    rotated = ROR(Rm, rotation);
    Rd = ZeroExtend(rotated<7:0>, 32);
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width  | Form                                            | Notes                                |
|---------|--------|-------------------------------------------------|--------------------------------------|
| T1      | 16-bit | `1011 0010 11 Rm Rd`                            | Low registers, no rotation.          |
| T2      | 32-bit | `11111010 0101 1111 1111 Rd 10 rot Rm`          | Full registers; rotation 0/8/16/24.  |

## Exceptions / faults

- (none)

## Example

### Example 1 — unpack four bytes using only the rotation field

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ UXTB demo: unpack the four bytes of a packed pixel/word into separate
    @ 32-bit registers using only the rotation field (no LSR needed).
    ldr     r0, =0xAABBCCDD      @ packed bytes:  AA BB CC DD
    uxtb    r1, r0               @ r1 = 0x000000DD  (byte 0)
    uxtb    r2, r0, ROR #8       @ r2 = 0x000000CC  (byte 1)
    uxtb    r3, r0, ROR #16      @ r3 = 0x000000BB  (byte 2)
    uxtb    r4, r0, ROR #24      @ r4 = 0x000000AA  (byte 3)
loop:
    b   loop
```

**Walkthrough:**

1. `uxtb r1, r0` — no rotation; takes the low byte. `r1 = 0x000000DD`. Equivalent to `r0 & 0xFF`.
2. `uxtb r2, r0, ROR #8` — first rotates `r0` right by 8 bits, then keeps the new low byte (which used to be byte 1). One cycle vs. an `LSR #8` plus `AND`.
3. The pattern repeats for `ROR #16` and `ROR #24`, picking bytes 2 and 3 respectively. This is *the* way to unpack a packed-byte word on Cortex-M33.

This is the part that bites people: only `0`, `8`, `16`, `24` are legal rotations. The assembler will reject `ROR #4`.

### Example 2 — mask a value to its low byte to form a table index

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ We just computed a 32-bit hash/mix in r0 and want to use its low
    @ byte as an index into a 256-entry lookup table.  UXTB does it in
    @ one instruction without loading a 0xFF constant.
    ldr     r0, =0x12345678      @ some computed 32-bit value
    uxtb    r1, r0               @ r1 = 0x78, ready for "ldrb r2, [tbl, r1]"
loop:
    b   loop
```

**Walkthrough:**

1. `ldr r0, =0x12345678` — pretend `r0` holds the result of arithmetic that left junk in the upper bytes.
2. `uxtb r1, r0` — keeps `r0[7:0]` and zeroes the rest. Now `r1` is a clean 0..255 index, safe to feed straight into `ldrb r2, [tbl, r1]`. Equivalent to `r0 & 0xFF` but without the literal-pool load `AND r1, r0, #0xFF` would need on values where the assembler can't synthesise the immediate.

## See also

- [SXTB](SXTB.md) — same shape but sign-extends instead of zero-extending.
- [UXTH](UXTH.md) — halfword version (16 → 32 bits).
- [UXTB16](UXTB16.md) — DSP variant that extracts two bytes into two halfwords at once.
- [UBFX](UBFX.md) — for arbitrary-width unsigned field extraction.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.227 — *UXTB*.
