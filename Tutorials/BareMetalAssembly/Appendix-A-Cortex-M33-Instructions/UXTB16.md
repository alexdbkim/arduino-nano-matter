# UXTB16 — zero-extend two bytes of a register into two halfwords  + DSP

## Class & availability

- **Class:** Bit manipulation (DSP-SIMD packing)
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅ (Cortex-M33 implements the DSP extension)
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UXTB16{<cond>} <Rd>, <Rm>{, ROR #<rotation>}
```

Optionally rotates `<Rm>` right by 0/8/16/24 bits, then takes bytes 0 and 2 of the rotated value, zero-extends each to 16 bits, and packs them into `<Rd>` as `Rd[15:0] = byte0`, `Rd[31:16] = byte2`. One instruction unpacks two bytes into two halfwords ready for parallel halfword arithmetic.

**When you'd actually use this** — staging unsigned-byte data for halfword SIMD: unpacking R/G/B/A channels of a packed pixel into halfword lanes for `UADD16`/`USUB16` blending, widening unsigned audio sample bytes for `SMLAD`-style filtering, or feeding any DSP routine that wants two `uint16_t` lanes per word. The scalar alternative is two separate `UXTB` extractions with shifts and packs — strictly more instructions. The signed counterpart is [`SXTB16`](SXTB16.md); pick that one whenever the source bytes are `int8_t`.

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
    Rd<15:0>  = ZeroExtend(rotated<7:0>,  16);   // byte 0 -> low halfword
    Rd<31:16> = ZeroExtend(rotated<23:16>, 16);  // byte 2 -> high halfword
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width  | Form                                            |
|---------|--------|-------------------------------------------------|
| T1      | 32-bit | `11111010 0011 1111 1111 Rd 10 rot Rm`          |

32-bit only. No 16-bit Thumb encoding.

## Exceptions / faults

- (none)

## Example

### Example 1 — unpack two bytes per call from a packed RGBA word

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ UXTB16 demo: take a packed RGBA-style word and unpack the R and B
    @ channels into two halfword lanes for SIMD halfword math (e.g. UADD16).
    ldr     r0, =0xAABBCCDD      @ bytes:  AA(byte3) BB(byte2) CC(byte1) DD(byte0)
    uxtb16  r1, r0               @ r1 = 0x00BB00DD  (byte2 hi, byte0 lo)
    uxtb16  r2, r0, ROR #8       @ rotate first: bytes -> DD AA BB CC
                                 @ r1-style extract: hi=byte2(=AA), lo=byte0(=CC)
                                 @ r2 = 0x00AA00CC
loop:
    b   loop
```

**Walkthrough:**

1. `ldr r0, =0xAABBCCDD` — four packed bytes, indexed 3..0 from MSB to LSB: `AA BB CC DD`.
2. `uxtb16 r1, r0` — picks bytes 0 and 2 (`DD` and `BB`), zero-extends each to a halfword, and packs them: low halfword = `0x00DD`, high halfword = `0x00BB`. Result `0x00BB00DD`.
3. `uxtb16 r2, r0, ROR #8` — first rotates right by 8, so bytes become `DD AA BB CC` (byte 0 = `CC`, byte 2 = `AA`). Picking bytes 0 and 2 now gives `0x00AA00CC`. Together, the two `UXTB16` instructions have unpacked all four bytes into halfword lanes — the standard prelude to running `UADD16`/`USUB16`/`SMLAD` over them.

This is the part that bites people: `UXTB16` does **not** unpack all four bytes by itself. You typically pair it with a second `UXTB16 …, ROR #8` (or with `UXTB16 …, ROR #16`) to cover the other two bytes.

### Example 2 — split a packed word into two `u16` lanes

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Quick sanity demo: r0 has four arbitrary bytes; UXTB16 picks
    @ bytes 0 and 2 and widens them into halfword lanes.
    ldr     r0, =0x12345678      @ bytes (3..0): 12 34 56 78
    uxtb16  r1, r0               @ r1 = 0x00340078  (hi=byte2=0x34, lo=byte0=0x78)
loop:
    b   loop
```

**Walkthrough:**

1. `ldr r0, =0x12345678` — bytes are `0x12 0x34 0x56 0x78` from MSB to LSB.
2. `uxtb16 r1, r0` — keeps bytes 0 and 2 (`0x78` and `0x34`), zero-extends each to a halfword, and packs them: low halfword = `0x0078`, high halfword = `0x0034`. Result `0x00340078`. From here `r1` is in the canonical "two unsigned halfword lanes" format that `UADD16`/`USUB16` consume directly. To grab the *other* two bytes, you'd do `uxtb16 r2, r0, ROR #8`.

## See also

- [SXTB16](SXTB16.md) — signed-extending counterpart.
- [UXTB](UXTB.md) — single-byte zero-extension into one full register.
- [UADD16](UADD16.md) / [USUB16](USUB16.md) — typical consumers of `UXTB16` output.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.228 — *UXTB16*.
