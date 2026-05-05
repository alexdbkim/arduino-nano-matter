# SMLALTB — Signed 16×16 multiply (top half of `Rn` × bottom half of `Rm`); accumulate the 32-bit product into a 64-bit `{RdHi:RdLo}` pair.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLALTB <RdLo>, <RdHi>, <Rn>, <Rm>
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<RdLo>` | low 32 bits of 64-bit accumulator (read+written) | R0–R12, LR; must differ from `<RdHi>` |
| `<RdHi>` | high 32 bits of 64-bit accumulator (read+written) | R0–R12, LR; must differ from `<RdLo>` |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |

## Operation (pseudocode)

```text
prod32 = SInt(Rn[31:16]) * SInt(Rm[15:0])
acc64  = (SInt(RdHi) << 32) | UInt(RdLo)
acc64  = acc64 + prod32
RdLo   = acc64[31:0]
RdHi   = acc64[63:32]
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

This instruction never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMLALTB` RdLo, RdHi, Rn, Rm |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

`Q` is **not** updated — a single 16×16 product can't overflow a 64-bit accumulator.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMLALTB demo: high(Rn) * low(Rm)
    movs    r0, #0
    movs    r1, #0
    ldr     r2, =0x7FFF0000
    ldr     r3, =0x00007FFF
    smlaltb r0, r1, r2, r3
loop:
    b   loop
```

**Walkthrough:**

1. Pack one int16 in `r2[31:16]` and another in `r3[15:0]`.
2. `smlaltb` does `Rn[31:16] * Rm[15:0]` and adds it to the 64-bit accumulator pair.

## See also

- [SMLALBB](SMLALBB.md) — 64-bit halfword MAC (BB)
- [SMLALBT](SMLALBT.md) — 64-bit halfword MAC (BT)
- [SMLALTT](SMLALTT.md) — 64-bit halfword MAC (TT)
- [SMLATB](SMLATB.md) — 32-bit accumulator equivalent
- [SMULTB](SMULTB.md) — no-accumulator product alone
- [SMLAL](SMLAL.md) — full 32×32 signed multiply-accumulate

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLALTB*.
