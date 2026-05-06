# QASX — signed saturating exchange-then-add-high/sub-low on packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
QASX <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `QASX` is the cross-lane swap-and-sat that complex DSP lives on. Lane layout in plain English: **top half of the result = top half of `Rn` PLUS bottom half of `Rm`; bottom half of the result = bottom half of `Rn` MINUS top half of `Rm`**. That's exactly the shuffle a complex multiply needs (real on top, imag on bottom), one half of every FFT butterfly, the rotation step of a Hilbert transform, and the in-place rotate of a 2D vector when combined with a multiply. Without `QASX` you'd need at least three or four instructions (`PKHBT`/`PKHTB` + scalar add + scalar sub + saturate) — `qasx` does the whole exchange-add/subtract-saturate in one cycle.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | `R0`–`R12`, `LR` (not `PC`/`SP`) |
| `<Rn>` | first source GPR | same constraints as `<Rd>` |
| `<Rm>` | second source GPR | same constraints as `<Rd>` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    h = SInt(Rn<31:16>) + SInt(Rm<15:0>)
    l = SInt(Rn<15:0>)  − SInt(Rm<31:16>)
    Rd<31:16> = SignedSat(h, 16)
    Rd<15:0>  = SignedSat(l, 16)
```

`QASX` treats each 32-bit register as two 16-bit lanes packed in each 32-bit register (halves swapped on Rm) and applies the signed saturating (clamps to lane range) rule independently to every lane.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never sets `N`/`Z`/`C`/`V`/`GE`. Crucially — and unlike scalar `QADD`/`QSUB` — the SIMD saturating variants do **not** set `APSR.Q` either. Saturation is silent; if you need to detect it, compare the result yourself.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | Thumb-2 only — there is **no** 16-bit encoding |

There is no 16-bit Thumb encoding for this instruction; the assembler always emits the 32-bit form.

## Exceptions / faults

- (none) — register-to-register only, no memory access.

## Example

### Example 1 — minimal packed-halfword signed cross add/subtract

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ QASX: cross add/sub on packed halfwords (used by complex-number kernels).
    movw    r1, #0x0005
    movt    r1, #0x0003
    movw    r2, #0x0002
    movt    r2, #0x0001
    qasx    r0, r1, r2          @ r0[hi]=r1[hi] + r2[lo], r0[lo]=r1[lo] − r2[hi]
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `qasx r0, r1, r2` exchanges the halves of `r2` first, then computes `r0[hi] = r1[hi] + r2[lo]` and `r0[lo] = r1[lo] − r2[hi]`.
3. Each half is then **saturated** to the signed 16-bit range `[−32768, 32767]`.

### Example 2 — complex multiply real-part cross step

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Building block of (a+jb)*(c+jd) where Rn = a:b (hi:lo, signed 16-bit)
    @ and Rm = c:d. The "real part" cross combines a*c on top with -b*d on
    @ bottom; the qasx primitive captures the +/- crossover pattern after the
    @ multiplies have been done lane-wise.
    movw    r0, #0x0064         @ b =  +100
    movt    r0, #0x012C         @ a =  +300
    movw    r1, #0x0032         @ d =  +50
    movt    r1, #0x00C8         @ c =  +200
    qasx    r2, r0, r1          @ hi = sat(a + d), lo = sat(b - c)
loop:
    b   loop
```

**Walkthrough:**

1. `r0` packs `a` (high half) and `b` (low half); `r1` packs `c` (high) and `d` (low).
2. `qasx` produces `r2_hi = sat(a + d) = sat(300+50) = +350` and `r2_lo = sat(b − c) = sat(100−200) = −100`, all in one cycle and each lane independently clamped to `[−32768, +32767]`.
3. This is the exact lane shuffle a complex-arithmetic cross-term step needs; without `qasx` it takes a `PKHBT`/`PKHTB` rearrangement plus separate add and subtract with manual saturation — at least 3–4 cycles versus 1.

## See also

- [QADD8](QADD8.md) — same family
- [QADD16](QADD16.md) — same family
- [QSUB8](QSUB8.md) — same family
- [QSAX](QSAX.md) — mirror operation (subtract on hi, add on lo)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *QASX*.
