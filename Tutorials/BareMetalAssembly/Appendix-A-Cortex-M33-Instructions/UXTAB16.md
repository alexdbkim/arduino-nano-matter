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

**When you'd actually use this** is the *vectorised* RGBA channel accumulator: lane 0 of `Rm` (byte [7:0]) and lane 2 (byte [23:16]) — which in a little-endian RGBA layout are the R and B channels of a pixel — get zero-extended to 16 bits and added into two parallel halfword accumulators in one cycle. A second `UXTAB16` with `ROR #8` picks up G and A. So two instructions accumulate R, G, B and A of a pixel into four 16-bit running sums — versus eight scalar `UXTB`/`ADD`s and several scratch registers. This is the inner step of fast image-statistics, white-balance, and Bayer-channel summation kernels.

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

### Example 1 — widening two unsigned bytes into halfword accumulators

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

### Example 2 — accumulating R and B channels of an RGBA pixel pair

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Image stats: sum R and B channels across two RGBA pixels into two
    @ parallel 16-bit lanes (lane0 = ΣR, lane2 = ΣB). One UXTAB16 per pixel.
    @ Little-endian RGBA: byte0=R, byte1=G, byte2=B, byte3=A.
    ldr     r0, =0x00000000      @ r0 = [ΣB | ΣR] running halfword sums
    ldr     r1, =0x80FF40C0      @ pixel #1: R=0xC0, G=0x40, B=0xFF, A=0x80
    uxtab16 r0, r0, r1           @ ΣR += 0xC0,  ΣB += 0xFF
    ldr     r1, =0x40AA20F0      @ pixel #2: R=0xF0, G=0x20, B=0xAA, A=0x40
    uxtab16 r0, r0, r1           @ ΣR += 0xF0,  ΣB += 0xAA
    @ ΣR = 0xC0 + 0xF0 = 0x01B0 (lane0)
    @ ΣB = 0xFF + 0xAA = 0x01A9 (lane2)
    @ r0 = 0x01A9_01B0
loop:
    b   loop
```

**Walkthrough:**

1. `r0` packs two halfword accumulators side-by-side: lane 0 (`ΣR`) and lane 2 (`ΣB`). Lane 1 / lane 3 of `r0` are unused — UXTAB16 only touches lanes 0 and 2.
2. Each `uxtab16` zero-extends the R byte (bits [7:0]) and B byte (bits [23:16]) of the source pixel and lane-wise adds to `r0` — one cycle for two byte-widens and two halfword-adds.
3. To sum G and A in parallel, run another `uxtab16 r2, r2, r1, ror #8` with `r2` holding `[ΣA | ΣG]`. Two instructions per pixel, four channels, no scratch register. Compare the scalar version: eight `UXTB`/`ADD`s plus shifts.

## See also

- [SXTAB16](SXTAB16.md) — signed counterpart
- [UXTAB](UXTAB.md) — single-byte form
- [UXTB16](UXTB16.md) — extend without the add
- [UADD16](UADD16.md) — once you've widened, sum halfwords in pairs

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *UXTAB16*.
