# SXTB16 — sign-extend two bytes of a register into two halfwords  + DSP

## Class & availability

- **Class:** Bit manipulation (DSP-SIMD packing)
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅ (Cortex-M33 implements the DSP extension)
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SXTB16{<cond>} <Rd>, <Rm>{, ROR #<rotation>}
```

Optionally rotates `<Rm>` right by 0/8/16/24 bits, then takes bytes 0 and 2 of the rotated value, **sign-extends** each to 16 bits, and packs them into `<Rd>`: `Rd[15:0] = SX(byte0)`, `Rd[31:16] = SX(byte2)`. The signed twin of [`UXTB16`](UXTB16.md), used to feed signed halfword SIMD ops with byte-sized source data.

**When you'd actually use this** — staging signed-byte data for halfword SIMD multiply/accumulate. The Cortex-M33 DSP ops `SMLAD`, `SMUAD`, `QADD16`, `SADD16` work on pairs of *signed 16-bit* lanes; if your input is bytes (audio samples, signed FIR coefficients, signed pixel deltas) you need to widen them first. `SXTB16` widens two bytes at a time into two halfword lanes — and gets the sign right. The wrong choice here is `UXTB16`, which silently turns `-1` into `+255` and quietly destroys your filter.

## Operands

| Field        | Type        | Constraints                                       |
|--------------|-------------|---------------------------------------------------|
| `<Rd>`       | destination | R0–R12, LR. Not SP, not PC.                       |
| `<Rm>`       | source      | R0–R12, LR. Not SP, not PC.                       |
| `<rotation>` | immediate   | `0`, `8`, `16`, or `24`. Optional; default `0`.   |

## Operation (pseudocode)

```text
if ConditionPassed() then
    rotated = ROR(Rm, rotation);
    Rd<15:0>  = SignExtend(rotated<7:0>,  16);   // byte 0 -> low halfword
    Rd<31:16> = SignExtend(rotated<23:16>, 16);  // byte 2 -> high halfword
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width  | Form                                            |
|---------|--------|-------------------------------------------------|
| T1      | 32-bit | `11111010 0010 1111 1111 Rd 10 rot Rm`          |

32-bit only. No 16-bit Thumb encoding.

## Exceptions / faults

- (none)

## Example

### Example 1 — unpack four signed bytes into halfword lanes

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SXTB16 demo: unpack two signed 8-bit audio samples per byte-pair
    @ into two halfword lanes ready for SMLAD-style filtering.
    ldr     r0, =0xFE7F8001      @ bytes (3..0):  FE  7F  80  01
                                 @ as int8_t:    -2 +127 -128 +1
    sxtb16  r1, r0               @ extract byte0 (+1) and byte2 (+127), sign-extended
    @ r1 = 0x007F0001  (hi = +127, lo = +1)

    sxtb16  r2, r0, ROR #8       @ rotate first: bytes become 01 FE 7F 80
                                 @ extract byte0 (-128 = 0x80) and byte2 (-2 = 0xFE)
    @ r2 = 0xFFFEFF80  (hi = -2,  lo = -128)
loop:
    b   loop
```

**Walkthrough:**

1. `ldr r0, =0xFE7F8001` — four signed bytes packed as `int8_t`: `-2`, `+127`, `-128`, `+1`.
2. `sxtb16 r1, r0` — picks bytes 0 (`0x01`) and 2 (`0x7F`). Both are positive, so the upper bits of each halfword are zero. Result `0x007F0001`.
3. `sxtb16 r2, r0, ROR #8` — rotation lines up bytes 1 and 3 (`0x80` and `0xFE`) into the byte-0 / byte-2 slots. Both are negative, so each halfword is sign-extended with ones: low halfword `0xFF80` (-128), high halfword `0xFFFE` (-2). Result `0xFFFEFF80`. Two `SXTB16` calls together have unpacked all four signed bytes into halfword lanes for `SMLAD`/`SMUAD`/`QADD16`-style work.

This is the part that bites people: `SXTB16` covers two of four bytes per call. Always plan for a paired `ROR #8` (or `ROR #24`) to grab the other two — and don't accidentally use `UXTB16`, which silently turns `-1` into `+255`.

### Example 2 — prepare two signed coefficients for `SMLAD`

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Two signed-byte FIR coefficients are packed in r0 at byte 0 (+1)
    @ and byte 2 (-128). SXTB16 widens both to halfword lanes in one
    @ shot so we can hand them to SMLAD/SMUAD without further fuss.
    ldr     r0, =0x00800001     @ byte2 = 0x80 (-128 as int8_t), byte0 = 0x01 (+1)
    sxtb16  r1, r0              @ r1 hi = 0xFF80 (-128), lo = 0x0001 (+1)
loop:
    b   loop
```

**Walkthrough:**

1. `ldr r0, =0x00800001` — pretend you just loaded a packed pair of signed coefficients. Byte 0 is `+1`; byte 2 is `0x80` which as `int8_t` means `-128`.
2. `sxtb16 r1, r0` — picks bytes 0 and 2, sign-extends each to 16 bits, and packs them: low halfword `0x0001` (+1), high halfword `0xFF80` (-128). Now `r1` is in the exact format `SMLAD`/`SMUAD` expect for its multiplicands.

## See also

- [UXTB16](UXTB16.md) — unsigned counterpart.
- [SXTB](SXTB.md) — single-byte sign-extension.
- [SMLAD](SMLAD.md) / [SMUAD](SMUAD.md) — typical consumers of `SXTB16` output.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.198 — *SXTB16*.
