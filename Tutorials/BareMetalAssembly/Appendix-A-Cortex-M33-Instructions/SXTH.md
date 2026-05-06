# SXTH — sign-extend a halfword from a register to 32 bits, with optional rotation

## Class & availability

- **Class:** Bit manipulation
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SXTH{<cond>} <Rd>, <Rm>{, ROR #<rotation>}
```

Optionally rotates `<Rm>` right by 0/8/16/24 bits, takes the bottom 16 bits of the rotated value, and sign-extends to 32 bits in `<Rd>`.

**When you'd actually use this** — when an `int16_t` lives in the low (or, with `ROR #16`, the high) half of a register: an I²S audio sample after a packed load, a signed sensor reading after `LDRH`, or a halfword field unpacked from a register. `SXTH` is the one-instruction alternative to `LSL #16 ; ASR #16` whenever the halfword sits at a halfword boundary; if it doesn't, reach for [`SBFX`](SBFX.md) instead.

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
    Rd = SignExtend(rotated<15:0>, 32);
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width  | Form                                            | Notes                                |
|---------|--------|-------------------------------------------------|--------------------------------------|
| T1      | 16-bit | `1011 0010 00 Rm Rd`                            | Low registers, no rotation.          |
| T2      | 32-bit | `11111010 0000 1111 1111 Rd 10 rot Rm`          | Full registers; rotation 0/8/16/24.  |

## Exceptions / faults

- (none)

## Example

### Example 1 — sign-extend the upper sample of a packed I²S word

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SXTH demo: extract a signed 16-bit audio sample from the upper half
    @ of a 32-bit word (typical of I2S DMA buffers).
    ldr     r0, =0x80000001      @ upper sample = 0x8000 (= -32768 signed)
    sxth    r1, r0, ROR #16      @ rotate so upper -> lower, then SX
    @ r1 = 0xFFFF8000 (-32768)

    @ Lower half is +1, sign-extending it is a no-op for the high bits
    sxth    r2, r0               @ r2 = 0x00000001
loop:
    b   loop
```

**Walkthrough:**

1. `ldr r0, =0x80000001` — packed: upper halfword `0x8000` (the most-negative `int16_t`), lower halfword `0x0001`.
2. `sxth r1, r0, ROR #16` — rotates right by 16, then sign-extends the resulting low halfword. `0x8000` has bit 15 set, so bits 31..16 of `r1` become ones, yielding `0xFFFF8000` — the correct 32-bit signed `-32768`.
3. `sxth r2, r0` — the lower halfword is `+1`; bit 15 is `0`, so the upper bits are zero. `r2 = 1`.

Use `SXTH` instead of `LSL #16 ; ASR #16` whenever the source halfword is already at a halfword boundary.

### Example 2 — sign-extend a small negative reading after `LDRH`

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ A native-LE I2C sensor returned a signed 16-bit value of -32 in
    @ the low halfword of r0 (0xFFE0). Bits 31..16 are zero because
    @ LDRH zero-extended.  We need a real 32-bit signed -32.
    ldr     r0, =0x0000FFE0      @ low halfword = 0xFFE0 (= -32 signed)
    sxth    r1, r0               @ r1 = 0xFFFFFFE0 (-32 in 32-bit form)
loop:
    b   loop
```

**Walkthrough:**

1. `ldr r0, =0x0000FFE0` — stand-in for the result of `ldrh r0, [rSensor]`. The sample is `-32` as an `int16_t`, but the load zero-extended it.
2. `sxth r1, r0` — sees bit 15 is `1` and fills bits 31..16 with ones, producing `0xFFFFFFE0`. From here `r1` participates correctly in any 32-bit signed arithmetic. (For *big-endian* sensors, [`REVSH`](REVSH.md) does the byte-swap and this sign-extension as a single instruction.)

## See also

- [UXTH](UXTH.md) — zero-extending counterpart.
- [SXTB](SXTB.md) — byte version.
- [REVSH](REVSH.md) — does byte-swap *and* sign-extend in one step.
- [SBFX](SBFX.md) — arbitrary-width signed extraction.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.199 — *SXTH*.
