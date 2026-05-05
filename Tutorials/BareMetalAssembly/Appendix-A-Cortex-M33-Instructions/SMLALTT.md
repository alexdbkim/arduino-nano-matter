# SMLALTT — Signed 16×16 multiply (top half of `Rn` × top half of `Rm`); accumulate the 32-bit product into a 64-bit `{RdHi:RdLo}` pair.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLALTT <RdLo>, <RdHi>, <Rn>, <Rm>
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
prod32 = SInt(Rn[31:16]) * SInt(Rm[31:16])
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
| T1 | 32-bit | `SMLALTT` RdLo, RdHi, Rn, Rm |

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
    @ SMLALTT demo: top halves into 64-bit accumulator
    movs    r0, #0
    movs    r1, #0
    ldr     r2, =0x00050000
    ldr     r3, =0x00060000
    smlaltt r0, r1, r2, r3      @ {r1:r0} += 5*6 = 30
loop:
    b   loop
```

**Walkthrough:**

1. Top halves of both operands held as int16.
2. `smlaltt` adds their product to `{RdHi:RdLo}` — the long-accumulator twin of `SMULTT`.

## See also

- [SMLALBB](SMLALBB.md) — 64-bit halfword MAC (BB)
- [SMLALBT](SMLALBT.md) — 64-bit halfword MAC (BT)
- [SMLALTB](SMLALTB.md) — 64-bit halfword MAC (TB)
- [SMLATT](SMLATT.md) — 32-bit accumulator equivalent
- [SMULTT](SMULTT.md) — no-accumulator product alone
- [SMLAL](SMLAL.md) — full 32×32 signed multiply-accumulate

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLALTT*.
