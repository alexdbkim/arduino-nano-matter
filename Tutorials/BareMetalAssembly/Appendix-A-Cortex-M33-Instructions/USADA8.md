# USADA8 — sum of absolute differences, accumulated into a third register

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
USADA8  <Rd>, <Rn>, <Rm>, <Ra>
```

Same per-byte unsigned-absolute-difference sum as `USAD8`, then adds `Ra` to the result. Use it to accumulate SAD across many 4-byte chunks without an extra `ADD`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR |
| `<Rn>` | first packed-byte source | R0–R12, LR |
| `<Rm>` | second packed-byte source | R0–R12, LR |
| `<Ra>` | accumulator input | R0–R12, LR; PC = `USAD8` (no accumulate) |

Per-instruction max addition is 1020, so a 32-bit accumulator overflows only after ≈ 4.2M chunks — fine for any realistic block size.

## Operation (pseudocode)

```text
if ConditionPassed() then
    absdiff0 = Abs(UInt(Rn<7:0>)   - UInt(Rm<7:0>))
    absdiff1 = Abs(UInt(Rn<15:8>)  - UInt(Rm<15:8>))
    absdiff2 = Abs(UInt(Rn<23:16>) - UInt(Rm<23:16>))
    absdiff3 = Abs(UInt(Rn<31:24>) - UInt(Rm<31:24>))
    Rd = Ra + absdiff0 + absdiff1 + absdiff2 + absdiff3
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates APSR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1111 1011 0111 Rn Ra Rd 0000 Rm` (`Ra != 1111`) |

When `Ra = 0b1111` the encoding is `USAD8` instead. 32-bit only.

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
    @ USADA8 demo: SAD across an 8-byte block (two 4-byte chunks), single accumulator
    ldr     r0, =0x10203040     @ block A, bytes 0..3
    ldr     r1, =0x50607080     @ block A, bytes 4..7
    ldr     r2, =0x12223843     @ block B, bytes 0..3
    ldr     r3, =0x52647483     @ block B, bytes 4..7
    movs    r4, #0              @ running SAD = 0
    usada8  r4, r0, r2, r4      @ r4 += |A0-B0|+|A1-B1|+|A2-B2|+|A3-B3|
    usada8  r4, r1, r3, r4      @ r4 += |A4-B4|+|A5-B5|+|A6-B6|+|A7-B7|
loop:
    b   loop
```

**Walkthrough:**

1. `movs r4, #0` — clear the running SAD accumulator. Always do this; reading garbage into `Ra` will silently bias the result.
2. First `usada8 r4, r0, r2, r4` — four absolute byte differences for the first chunk, added into `r4`.
3. Second `usada8 r4, r1, r3, r4` — four more, added on top. After two instructions you have the full 8-byte SAD with no separate `ADD`.

Real motion-estimation kernels unroll this across an 8×8 or 16×16 block — each row costs two `USADA8`s.

## See also

- [USAD8](USAD8.md) — non-accumulating variant
- [SMLAD](SMLAD.md) — dual signed multiply-accumulate, the multiply-side cousin
- [UADD8](UADD8.md) — unsigned per-byte add, GE-flagged

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *USADA8*.
