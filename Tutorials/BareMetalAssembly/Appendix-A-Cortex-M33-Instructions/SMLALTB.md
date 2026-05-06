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

**When you'd actually use this:** `SMLALTB` multiplies the **top** half of `Rn` by the **bottom** half of `Rm` and adds the signed 32-bit product into a 64-bit `{RdHi:RdLo}` pair. The 64-bit accumulator is the entire point — a Q15 × Q15 product fits in 30 bits, so a 32-bit accumulator overflows fast in long chains, while 64 bits gives you ~32 bits of headroom and lets you sum millions of taps before clipping. The "TB" mix is perfect for stereo/mixed-stream layouts: e.g. a packed-frame word holding `(left|right)` paired with a packed-gains word holding `(gainL|gainR)` — one instruction routes the left sample into the right-channel bus without any shifting. Without it, you'd hand-shift with `ASR #16` + `SXTH` + `MUL` + `ADDS` + `ADC` per tap — five instructions and a scratch register vs. one.

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

### Example 1 — single top×bottom MAC seed

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

### Example 2 — stereo cross-channel mix accumulator

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  stereo_cross_mix
    .thumb_func
stereo_cross_mix:
    @ Frames packed as (Left in top half | Right in bottom half).
    @ Gains  packed as (gainL in top half | gainR in bottom half).
    @ We sum Left * gainR -- left signal routed into right bus.
    @ r0 = frame ptr, r1 = gains ptr (constant), r2 = N frames
    push    {r4-r6, lr}
    movs    r3, #0              @ acc lo
    movs    r4, #0              @ acc hi
    ldr     r6, [r1]            @ load packed gains once
1:  ldr     r5, [r0], #4        @ next frame: top=L, bot=R
    smlaltb r3, r4, r5, r6      @ {r4:r3} += L * gainR
    subs    r2, r2, #1
    bne     1b
    pop     {r4-r6, pc}
```

**Walkthrough:**

1. Each frame word stores Left in the top half and Right in the bottom half (one `LDR` brings both at once).
2. `SMLALTB` picks **top of `r5`** (Left) and **bottom of `r6`** (gainR) — exactly the cross-channel pair we want — and adds the product to `{r4:r3}` in a single cycle.
3. Run this over an entire audio buffer (say 48 kHz × 1 s = 48 000 frames) and the 64-bit accumulator never overflows even at full-scale Q15 input: `48000 × (2^15)^2 ≈ 2^46`, well below 2^63. A 32-bit accumulator would have wrapped after ~256 frames worst case — that's the whole reason `SMLAL*` exists.
4. Pair this with `SMLALBT` on the same registers to sum Right × gainL into a different accumulator pair, and you've built one half of a 2×2 mixer matrix with two MAC instructions per frame.

## See also

- [SMLALBB](SMLALBB.md) — 64-bit halfword MAC (BB)
- [SMLALBT](SMLALBT.md) — 64-bit halfword MAC (BT)
- [SMLALTT](SMLALTT.md) — 64-bit halfword MAC (TT)
- [SMLATB](SMLATB.md) — 32-bit accumulator equivalent
- [SMULTB](SMULTB.md) — no-accumulator product alone
- [SMLAL](SMLAL.md) — full 32×32 signed multiply-accumulate

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLALTB*.
