# USAX — unsigned wrap-around exchange-then-sub-high/add-low on packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
USAX <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `USAX` mirrors `UASX`: subtract on the high lane, add on the low (after swapping `Rm`'s halves). It comes up in FFT butterflies, complex-multiply kernels, and 2D rotate-and-translate sequences in image processing — anywhere `(a−d, b+c)` is the right packed shape. The result wraps mod-2^16 (no saturation), and **the four `APSR.GE` bits are updated per halfword lane** so a follow-up `SEL` can per-lane select. That's the killer feature: without `GE`+`SEL`, byte/halfword conditional logic costs ~6–10 scalar instructions; with them, two.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | `R0`–`R12`, `LR` (not `PC`/`SP`) |
| `<Rn>` | first source GPR | same constraints as `<Rd>` |
| `<Rm>` | second source GPR | same constraints as `<Rd>` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    h = UInt(Rn<31:16>) − UInt(Rm<15:0>)
    l = UInt(Rn<15:0>)  + UInt(Rm<31:16>)
    Rd<31:16> = h<15:0>
    Rd<15:0>  = l<15:0>
    APSR.GE<3:2> = lane_ok(h)
    APSR.GE<1:0> = lane_ok(l)
```

`USAX` treats each 32-bit register as two 16-bit lanes packed in each 32-bit register (halves swapped on Rm) and applies the modulo (wrap-around) rule independently to every lane.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never sets `N`/`Z`/`C`/`V`/`Q`. Updates `APSR.GE[3:0]` per lane: one bit per byte for `…8` variants, two duplicated bits per halfword for `…16`/ASX/SAX variants. Pair with `SEL` to consume them.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | Thumb-2 only — there is **no** 16-bit encoding |

There is no 16-bit Thumb encoding for this instruction; the assembler always emits the 32-bit form.

## Exceptions / faults

- (none) — register-to-register only, no memory access.

## Example

### Example 1 — Reverse-cross sub/add on packed halfwords

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ USAX: reverse-cross sub/add on packed halfwords.
    movw    r1, #0x0005
    movt    r1, #0x0003
    movw    r2, #0x0002
    movt    r2, #0x0001
    usax    r0, r1, r2          @ r0[hi]=r1[hi] − r2[lo], r0[lo]=r1[lo] + r2[hi]
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `usax r0, r1, r2` exchanges the halves of `r2` first, then computes `r0[hi] = r1[hi] − r2[lo]` and `r0[lo] = r1[lo] + r2[hi]`.
3. `APSR.GE[3:2]` reflects the high-half result, `GE[1:0]` the low-half result.

### Example 2 — 2D skew + translate step in graphics

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Skew + translate one (x, y) point packed as halfwords, with deltas (dx, dy) in r2.
    @ USAX yields (x − dy, y + dx) — a single packed step of a "−90° rotate + add" kernel.
    movw    r1, #0x0040              @ y = 0x0040 (low half)
    movt    r1, #0x0080              @ x = 0x0080 (high half)
    movw    r2, #0x0003              @ dy = 3 (low half of r2)
    movt    r2, #0x0002              @ dx = 2 (high half of r2)
    usax    r0, r1, r2               @ r0[hi]=x − dy = 0x007D, r0[lo]=y + dx = 0x0042
loop:
    b   loop
```

**Walkthrough:**

1. Packing 2D coords as halfwords lets one SIMD op transform both axes in a single cycle.
2. `USAX`'s "subtract-high, add-low after swap" pattern drops out naturally for `−90°` rotation steps and certain shear transforms.
3. The four `APSR.GE` bits flag per-lane carry/borrow — feed them to `SEL` to clamp coordinates to a viewport in just one extra instruction.

## See also

- [UADD8](UADD8.md) — same family
- [UADD16](UADD16.md) — same family
- [USUB8](USUB8.md) — same family
- [UASX](UASX.md) — mirror operation (add on hi, subtract on lo)
- [SEL](SEL.md) — consume the GE flags this instruction sets

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *USAX*.
