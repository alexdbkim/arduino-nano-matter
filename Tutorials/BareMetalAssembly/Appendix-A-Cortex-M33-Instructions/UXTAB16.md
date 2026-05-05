# UXTAB16 — extract two bytes from Rm, zero-extend each to 16 bits, add to Rn (SIMD)

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UXTAB16  <Rd>, <Rn>, <Rm>{, ROR #<amount>}
```

SIMD form: take bytes [7:0] and [23:16] from the rotated `Rm`, zero-extend each to 16 bits, then add them lane-wise to the two halfwords of `Rn`. The unsigned twin of `SXTAB16`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR |
| `<Rn>` | two packed unsigned halfwords to add into | R0–R12, LR; `Rn = PC` is `UXTB16` |
| `<Rm>` | source for the two bytes | R0–R12, LR |
| `<amount>` | rotation before extraction | 0, 8, 16, or 24 (default 0) |

## Operation (pseudocode)

```text
if ConditionPassed() then
    rotated = ROR(Rm, amount)
    Rd<15:0>  = Rn<15:0>  + ZeroExtend(rotated<7:0>,   16)
    Rd<31:16> = Rn<31:16> + ZeroExtend(rotated<23:16>, 16)
```

Each lane add wraps modulo 2^16 — there's no saturation and no inter-lane carry. That last point bites people: a halfword result of `0x10000` truncates to `0x0000`, silently.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates APSR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1111 1010 0011 Rn 1111 Rd 10 rot Rm` (`Rn != 1111`) |

`Rn = 0b1111` becomes `UXTB16`. 32-bit only.

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
    @ UXTAB16 demo: widen two unsigned pixel bytes into two 16-bit accumulators
    ldr     r0, =0x00100020     @ Rn: lane0 = 0x0020, lane2 = 0x0010
    ldr     r1, =0xAA80FF40     @ Rm: byte at [7:0]=0x40 (64), byte at [23:16]=0x80 (128)
    uxtab16 r2, r0, r1          @ lane0: 0x0020 + 64  = 0x0060
                                @ lane2: 0x0010 + 128 = 0x0090
                                @ r2 = 0x0090_0060
loop:
    b   loop
```

**Walkthrough:**

1. `ldr r0, ...` / `ldr r1, ...` — `r0` is two 16-bit accumulators, `r1` four packed bytes.
2. `uxtab16 r2, r0, r1` — bytes 0 and 2 of `r1` are zero-extended to halfwords (64 and 128) and added to the matching halves of `r0`. Two byte→halfword promotions and two adds for the price of one instruction.

Two `UXTAB16` calls — one with `ROR #0`, one with `ROR #8` — process all four bytes of a packed-pixel word into four halfword accumulators (using two destination registers).

## See also

- [SXTAB16](SXTAB16.md) — signed counterpart
- [UXTAB](UXTAB.md) — single-byte form
- [UXTB16](UXTB16.md) — extend without the add
- [UADD16](UADD16.md) — once you've widened, sum halfwords in pairs

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *UXTAB16*.
