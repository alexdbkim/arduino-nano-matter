# QSAX — signed saturating exchange-then-sub-high/add-low on packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
QSAX <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `QSAX` is the mirror of `QASX`: lane layout is **top half of result = top half of `Rn` MINUS bottom half of `Rm`; bottom half of result = bottom half of `Rn` PLUS top half of `Rm`**. It's the partner instruction in complex multiplies (it produces the imaginary-output term while `QASX` produces the real-output term), and it's the second half of every radix-2 FFT butterfly. It's also the cleanest way to express "left+right on one lane, left−right on the other" mid-side stereo encoding when the channels are packed swapped. Without `QSAX`, the same lane shuffle costs 3–4 instructions and a manual saturate.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | `R0`–`R12`, `LR` (not `PC`/`SP`) |
| `<Rn>` | first source GPR | same constraints as `<Rd>` |
| `<Rm>` | second source GPR | same constraints as `<Rd>` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    h = SInt(Rn<31:16>) − SInt(Rm<15:0>)
    l = SInt(Rn<15:0>)  + SInt(Rm<31:16>)
    Rd<31:16> = SignedSat(h, 16)
    Rd<15:0>  = SignedSat(l, 16)
```

`QSAX` treats each 32-bit register as two 16-bit lanes packed in each 32-bit register (halves swapped on Rm) and applies the signed saturating (clamps to lane range) rule independently to every lane.

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

### Example 1 — minimal packed-halfword signed cross subtract/add

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ QSAX: reverse-cross sub/add on packed halfwords.
    movw    r1, #0x0005
    movt    r1, #0x0003
    movw    r2, #0x0002
    movt    r2, #0x0001
    qsax    r0, r1, r2          @ r0[hi]=r1[hi] − r2[lo], r0[lo]=r1[lo] + r2[hi]
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `qsax r0, r1, r2` exchanges the halves of `r2` first, then computes `r0[hi] = r1[hi] − r2[lo]` and `r0[lo] = r1[lo] + r2[hi]`.
3. Each half is then **saturated** to the signed 16-bit range `[−32768, 32767]`.

### Example 2 — complex multiply imaginary-part cross step

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Mirror of QASX: hi = sat(Rn_hi - Rm_lo), lo = sat(Rn_lo + Rm_hi).
    @ With Rn = a:b and Rm = c:d this captures (a-d) on top and (b+c) on
    @ bottom -- the imaginary-output cross pattern of complex multiply.
    movw    r0, #0x0064         @ b = +100
    movt    r0, #0x012C         @ a = +300
    movw    r1, #0x0032         @ d = +50
    movt    r1, #0x00C8         @ c = +200
    qsax    r2, r0, r1          @ hi = sat(a - d) = +250, lo = sat(b + c) = +300
loop:
    b   loop
```

**Walkthrough:**

1. `r0` is `a:b` (high:low), `r1` is `c:d`; `qsax` flips the operations relative to `qasx`.
2. `qsax` computes `r2_hi = sat(300 − 50) = +250` and `r2_lo = sat(100 + 200) = +300` simultaneously, with each lane clamped to signed-16 range.
3. Pairing `qasx` for the real cross term with `qsax` for the imaginary cross term is the canonical Cortex-M33 idiom for complex-number butterflies — 2 instructions instead of ~7 of scalar shuffling.

## See also

- [QADD8](QADD8.md) — same family
- [QADD16](QADD16.md) — same family
- [QSUB8](QSUB8.md) — same family
- [QASX](QASX.md) — mirror operation (add on hi, subtract on lo)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *QSAX*.
