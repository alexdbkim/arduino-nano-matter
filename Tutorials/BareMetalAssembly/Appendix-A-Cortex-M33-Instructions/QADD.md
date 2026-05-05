# QADD — saturating signed 32-bit add

## Class & availability

- **Class:** Saturation (DSP arithmetic)
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
QADD{<c>}{<q>} {<Rd>,} <Rm>, <Rn>
```

Computes `Rd = sat32(Rm + Rn)`, where the sum is treated as a signed 32-bit value and clipped to `INT32_MIN … INT32_MAX` instead of wrapping. Note the operand order: ARM ARM defines the operation as `Rm + Rn` (not `Rn + Rm`). For commutative add it doesn't matter, but it does matter for `QSUB`/`QDSUB`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR. If omitted, `Rd = Rm`. |
| `<Rm>` | first source (left addend) | R0–R12, LR |
| `<Rn>` | second source (right addend) | R0–R12, LR |

## Operation (pseudocode)

```text
if ConditionPassed() then
    (result, sat) = SignedSatQ(SInt(R[m]) + SInt(R[n]), 32)
    R[d] = result<31:0>
    if sat then APSR.Q = '1'    // sticky
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | ✓ |

`Q` is set when the true mathematical sum falls outside `[−2^31, 2^31−1]`. **Q is sticky** — only `MSR APSR_nzcvq, Rn` (bit 27 = 0) clears it. N/Z/C/V are untouched, which is why you usually pair `QADD` with an explicit compare if you need to branch on the result.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `QADD <Rd>, <Rm>, <Rn>` |

DSP-extension; 32-bit Thumb only.

## Exceptions / faults

- (none).

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Accumulate signed audio samples without 32-bit wrap-around.
    @ r4 = running sum, r5 = pointer to int32 samples, r6 = count.
    ldr     r5, =samples
    mov     r6, #4
    mov     r4, #0
acc_loop:
    ldr     r0, [r5], #4        @ load next sample, post-increment
    qadd    r4, r0, r4          @ r4 = sat(sample + accumulator)
    subs    r6, r6, #1
    bne     acc_loop

    @ At this point APSR.Q tells us "did the accumulator ever clip?"
    mrs     r1, apsr
    tst     r1, #(1 << 27)      @ Z = 0 if Q was set somewhere in the loop
    bic     r1, r1, #(1 << 27)
    msr     APSR_nzcvq, r1      @ clear sticky Q
loop:
    b   loop

    .align 2
samples:
    .word   0x40000000          @ +2^30
    .word   0x40000000          @ +2^30  (sum so far +2^31 — saturates!)
    .word   0x10000000
    .word   -0x20000000
```

**Walkthrough:**

1. `ldr r0, [r5], #4` — fetch the next signed sample and bump the pointer; classic DSP inner-loop load.
2. `qadd r4, r0, r4` — adds sample to running total. On the second iteration the true sum is `+2^31`, which exceeds `INT32_MAX`. Instead of wrapping to a huge negative number (the trap with plain `ADD`), `QADD` clamps `r4` to `0x7FFFFFFF` and latches `APSR.Q`. The accumulator now drifts a little, but it stays *the right sign* — much easier to recover from than a wrap.
3. `tst r1, #(1 << 27)` — non-destructive way to test the sticky `Q` bit after the loop. This is the typical "did we lose precision anywhere along the way?" check in audio/control loops.
4. `msr APSR_nzcvq, r1` — `Q` is *only* cleared by writing APSR through `MSR`. No arithmetic instruction, not even another `QADD` whose result fits, will clear it.

## See also

- [QSUB](QSUB.md) — saturating signed 32-bit subtract
- [QDADD](QDADD.md) — saturating `Rm + sat(2·Rn)` (Q15 multiplier-accumulate friend)
- [SSAT](SSAT.md) — clip an arbitrary 32-bit value to fewer bits
- [QADD16](QADD16.md) / [QADD8](QADD8.md) — saturating SIMD add on packed lanes

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.x — *QADD*.
