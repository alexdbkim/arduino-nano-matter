# SXTAB16 — extract two bytes from Rm, sign-extend each to 16 bits, add to Rn (SIMD)

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SXTAB16  <Rd>, <Rn>, <Rm>{, ROR #<amount>}
```

SIMD version of `SXTAB`. After an optional rotate of `Rm`, take bytes [7:0] and [23:16] in parallel, sign-extend each to 16 bits, and add them to the matching halves of `Rn`. Two byte-to-halfword extracts and two adds, one instruction.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR |
| `<Rn>` | two packed signed halfwords to add into | R0–R12, LR; `Rn = PC` is `SXTB16` |
| `<Rm>` | source for the two bytes | R0–R12, LR |
| `<amount>` | rotation before extraction | 0, 8, 16, or 24 (default 0) |

The two bytes selected are always `Rm[7:0]` and `Rm[23:16]` *after* the rotate — i.e. lanes 0 and 2 of the rotated value.

## Operation (pseudocode)

```text
if ConditionPassed() then
    rotated = ROR(Rm, amount)
    Rd<15:0>  = Rn<15:0>  + SignExtend(rotated<7:0>,   16)
    Rd<31:16> = Rn<31:16> + SignExtend(rotated<23:16>, 16)
```

Each lane add wraps modulo 2^16 inside its halfword — no saturation, no flags.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates APSR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1111 1010 0010 Rn 1111 Rd 10 rot Rm` (`Rn != 1111`) |

`Rn = 0b1111` becomes `SXTB16`. 32-bit only.

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
    @ SXTAB16 demo: unpack two signed bytes into two 16-bit accumulators in one go
    ldr     r0, =0x00100020     @ Rn: lane0 acc = +0x0020, lane2 acc = +0x0010
    ldr     r1, =0xAABBFF7F     @ Rm: byte at [7:0]=0x7F (+127), byte at [23:16]=0xBB (-69)
    sxtab16 r2, r0, r1          @ lane0: 0x0020 + (+127)  = 0x009F
                                @ lane2: 0x0010 + (-69)   = 0xFFCB
                                @ r2 = 0xFFCB_009F
loop:
    b   loop
```

**Walkthrough:**

1. `ldr r0, ...` / `ldr r1, ...` — `r0` holds two 16-bit accumulators, `r1` holds four bytes from which we pick two.
2. `sxtab16 r2, r0, r1` — the bottom byte of `r1` (`0x7F` = +127) is sign-extended and added to the bottom halfword of `r0`; byte at bits [23:16] of `r1` (`0xBB` = -69) is sign-extended and added to the top halfword of `r0`. Both half-adds happen in one cycle.

This is the natural way to widen packed signed bytes (think 8-bit audio or 8-bit pixel deltas) into a pair of 16-bit accumulators for further SIMD math.

## See also

- [SXTAB](SXTAB.md) — single-byte form
- [UXTAB16](UXTAB16.md) — zero-extending counterpart
- [SXTB16](SXTB16.md) — extend without the add
- [SADD16](SADD16.md) — once you've widened, add halfwords in pairs

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SXTAB16*.
