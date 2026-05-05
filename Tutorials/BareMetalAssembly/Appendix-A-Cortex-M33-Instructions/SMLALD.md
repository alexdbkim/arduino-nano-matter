# SMLALD — Dual signed 16×16 multiply, then sum the two products and accumulate into a 64-bit register pair.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLALD <RdLo>, <RdHi>, <Rn>, <Rm>
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
p1 = SInt(Rn[15:0])  * SInt(Rm[15:0])
p2 = SInt(Rn[31:16]) * SInt(Rm[31:16])
acc64 = (SInt(RdHi) << 32) | UInt(RdLo)
acc64 = acc64 + (p1 + p2)        // 64-bit signed add
RdLo = acc64[31:0]
RdHi = acc64[63:32]
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

This instruction never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMLALD` RdLo, RdHi, Rn, Rm |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

`Q` is **not** set by this instruction — a 64-bit accumulator cannot overflow on a single dual-product step.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMLALD demo: long-running FIR with overflow-safe accumulator
    movs    r0, #0              @ RdLo
    movs    r1, #0              @ RdHi
    ldr     r2, =0x7FFF7FFF     @ two big positive Q15 samples
    ldr     r3, =0x7FFF7FFF     @ two big positive Q15 coefficients
    smlald  r0, r1, r2, r3      @ {r1:r0} += s0*c0 + s1*c1
loop:
    b   loop
```

**Walkthrough:**

1. Zero a 64-bit accumulator in `{r1:r0}`.
2. Load two saturated Q15 lanes into each operand.
3. `smlald` adds both products into the 64-bit pair. Because the accumulator is 64-bit, you can run thousands of taps without ever needing to saturate — that's the whole point versus SMLAD.

## See also

- [SMLALDX](SMLALDX.md) — exchanged 64-bit dual MAC
- [SMLSLD](SMLSLD.md) — non-exchanged 64-bit dual multiply-subtract
- [SMLSLDX](SMLSLDX.md) — exchanged 64-bit dual multiply-subtract
- [SMLAD](SMLAD.md) — 32-bit accumulator equivalent
- [SMLAL](SMLAL.md) — plain signed 32×32 → 64 multiply-accumulate

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLALD*.
