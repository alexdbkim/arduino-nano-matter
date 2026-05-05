# SXTB — sign-extend a byte from a register to 32 bits, with optional rotation

## Class & availability

- **Class:** Bit manipulation
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SXTB{<cond>} <Rd>, <Rm>{, ROR #<rotation>}
```

Optionally rotates `<Rm>` right by 0/8/16/24 bits, takes the bottom 8 bits of the rotated value, and sign-extends to 32 bits in `<Rd>`. Use it after loading an unsigned byte (or unpacking one from a packed word) when you actually want a signed value.

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
    Rd = SignExtend(rotated<7:0>, 32);
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width  | Form                                            | Notes                                |
|---------|--------|-------------------------------------------------|--------------------------------------|
| T1      | 16-bit | `1011 0010 01 Rm Rd`                            | Low registers, no rotation.          |
| T2      | 32-bit | `11111010 0100 1111 1111 Rd 10 rot Rm`          | Full registers; rotation 0/8/16/24.  |

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
    @ SXTB demo: an accelerometer returns a signed 8-bit delta packed
    @ into bits [15:8] of a status word. We need it as a 32-bit signed int.
    ldr     r0, =0x0000FF00      @ delta byte = 0xFF (= -1 signed)
    sxtb    r1, r0, ROR #8       @ rotates so byte[1] -> low byte, then SX
    @ r1 = 0xFFFFFFFF (-1)

    @ Positive case: byte = 0x40 in the low position
    movs    r2, #0x40
    sxtb    r3, r2               @ r3 = 0x00000040 (+64), no fill needed
loop:
    b   loop
```

**Walkthrough:**

1. `ldr r0, =0x0000FF00` — the delta is in bits [15:8] of the packed word.
2. `sxtb r1, r0, ROR #8` — rotates right by 8 (so byte 1 becomes byte 0), then sign-extends. The byte was `0xFF`, which is `-1` as `int8_t`, so `r1` becomes `0xFFFFFFFF`.
3. `sxtb r3, r2` — when the byte is positive (`0x40`), bits 31..8 are filled with zeros, giving `+64`.

Use `SXTB` instead of `LSL #24 ; ASR #24` whenever the source byte already lives at a byte boundary — one instruction, one cycle.

## See also

- [UXTB](UXTB.md) — zero-extending counterpart.
- [SXTH](SXTH.md) — halfword version.
- [SXTB16](SXTB16.md) — DSP variant that sign-extends two bytes into two halfwords.
- [SBFX](SBFX.md) — for arbitrary-width signed extraction.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.197 — *SXTB*.
