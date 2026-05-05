# USAD8 — sum of absolute differences across four bytes

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
USAD8  <Rd>, <Rn>, <Rm>
```

Treats `Rn` and `Rm` as four unsigned bytes each, computes `|n[i] - m[i]|` per lane, and sums all four absolute differences into `Rd`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR; not SP, not PC |
| `<Rn>` | first packed-byte source | R0–R12, LR |
| `<Rm>` | second packed-byte source | R0–R12, LR |

The maximum result is `4 × 255 = 1020`, so it always fits in 16 bits — no overflow concern.

## Operation (pseudocode)

```text
if ConditionPassed() then
    absdiff0 = Abs(UInt(Rn<7:0>)   - UInt(Rm<7:0>))
    absdiff1 = Abs(UInt(Rn<15:8>)  - UInt(Rm<15:8>))
    absdiff2 = Abs(UInt(Rn<23:16>) - UInt(Rm<23:16>))
    absdiff3 = Abs(UInt(Rn<31:24>) - UInt(Rm<31:24>))
    Rd = absdiff0 + absdiff1 + absdiff2 + absdiff3
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

USAD8 never updates APSR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1111 1011 0111 Rn 1111 Rd 0000 Rm` |

There is no 16-bit Thumb encoding.

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
    @ USAD8 demo: SAD between two 4-byte pixel runs (motion-estimation kernel)
    ldr     r0, =0x10203040     @ block A: bytes 0x40,0x30,0x20,0x10
    ldr     r1, =0x12223843     @ block B: bytes 0x43,0x38,0x22,0x12
    usad8   r2, r0, r1          @ r2 = |40-43|+|30-38|+|20-22|+|10-12|
                                @     = 3 + 8 + 2 + 2 = 15
loop:
    b   loop
```

**Walkthrough:**

1. `ldr r0, =...` / `ldr r1, =...` — load two 32-bit words holding four packed bytes each. Think of them as a 1×4 pixel row from two video frames.
2. `usad8 r2, r0, r1` — for each byte lane, take the unsigned absolute difference, then sum all four. `r2 = 15`. This single instruction replaces a four-iteration loop with subtract/abs/accumulate.

This is the workhorse of block-matching motion search: smaller SAD = better match.

## See also

- [USADA8](USADA8.md) — same op, but accumulates into a third register (running total across many blocks)
- [SADD8](SADD8.md) — signed per-byte add, sets GE flags
- [SSUB8](SSUB8.md) — signed per-byte subtract, sets GE flags

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *USAD8*.
