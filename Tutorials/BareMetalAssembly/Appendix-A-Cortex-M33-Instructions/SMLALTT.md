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

**When you'd actually use this:** `SMLALTT` takes the **top** halves of both `Rn` and `Rm`, multiplies them as int16, and accumulates the signed product into a 64-bit `{RdHi:RdLo}` pair. The 64-bit accumulator is the hero: long FIR filters, sensor-fusion integrators, and per-frame energy summers all need many thousands of Q15 MACs to add up without clipping, and 32 bits just isn't enough headroom — 64 bits lets you sum millions of taps without a single saturation check. The "TT" form shines when your data layout puts both samples and coefficients in the *upper* half of packed words (common when a 16-bit ADC value is left-aligned into a 32-bit reading, or when coefficients are stored upper-half to free the lower half for a tag/index). Without `SMLALTT`, that same step costs `ASR #16` + `ASR #16` + `MUL` + `ADDS` + `ADC` per tap — roughly 5× the work and a scratch register.

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

### Example 1 — single top×top MAC seed

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

### Example 2 — coefficients packed in the upper half-word

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  fir_smlaltt_upper
    .thumb_func
fir_smlaltt_upper:
    @ Samples: int32[] where each word stores (sample16 | tag16) -- sample in TOP half.
    @ Coeffs:  int32[] where each word stores (coeff16  | flags16) -- coeff in TOP half.
    @ r0 = sample word ptr, r1 = coeff word ptr, r2 = N taps
    push    {r4-r6, lr}
    movs    r3, #0              @ acc lo
    movs    r4, #0              @ acc hi
1:  ldr     r5, [r0], #4        @ sample16 sits in r5[31:16], tag in r5[15:0]
    ldr     r6, [r1], #4        @ coeff16  sits in r6[31:16], flags in r6[15:0]
    smlaltt r3, r4, r5, r6      @ {r4:r3} += sample16 * coeff16, tag/flags ignored
    subs    r2, r2, #1
    bne     1b
    pop     {r4-r6, pc}
```

**Walkthrough:**

1. The data layout deliberately keeps the int16 payload in the upper half of each word, leaving the lower half for metadata (a frame tag, a coefficient enable flag, etc.).
2. `SMLALTT` reads both upper halves directly — the lower-half metadata is silently ignored, no masking needed.
3. One `LDR` + one `SMLALTT` per tap, just like the bottom-half FIR — but now you get a free side-channel of metadata you can reuse elsewhere without a separate parallel array.
4. The 64-bit accumulator is what makes this safe at scale: a 4096-tap filter on full-scale Q15 input reaches `4096 × (2^15-1)^2 ≈ 2^42`, leaving 21 bits of headroom in `{r4:r3}`. The same loop with a 32-bit accumulator would overflow after ~512 taps. That headroom — without any saturation logic — is the whole reason this instruction earns its slot in the M33 ISA.

## See also

- [SMLALBB](SMLALBB.md) — 64-bit halfword MAC (BB)
- [SMLALBT](SMLALBT.md) — 64-bit halfword MAC (BT)
- [SMLALTB](SMLALTB.md) — 64-bit halfword MAC (TB)
- [SMLATT](SMLATT.md) — 32-bit accumulator equivalent
- [SMULTT](SMULTT.md) — no-accumulator product alone
- [SMLAL](SMLAL.md) — full 32×32 signed multiply-accumulate

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLALTT*.
