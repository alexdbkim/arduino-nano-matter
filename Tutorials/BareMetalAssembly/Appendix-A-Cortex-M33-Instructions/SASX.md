# SASX — signed wrap-around exchange-then-add-high/sub-low on packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SASX <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `SASX` is the un-saturating sibling of `QASX`. The cross-pattern (add the high lane after swapping `Rm`'s halves, subtract the low lane) is exactly the shape that drops out of FFT butterflies, complex multiplies, and 2D rotation kernels in image processing — anywhere you need `(a+d, b−c)` from packed pairs `(a,b)` and `(c,d)`. **It also writes `APSR.GE`** — top two bits for the high halfword lane, bottom two for the low — so a follow-up `SEL` can mask or merge based on each lane's sign. Doing the same work with two scalar pairs costs roughly twice the instructions and loses the per-lane flag side-effect, which is the whole reason `SEL` exists.

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
    Rd<31:16> = h<15:0>
    Rd<15:0>  = l<15:0>
    APSR.GE<3:2> = lane_ok(h)
    APSR.GE<1:0> = lane_ok(l)
```

`SASX` treats each 32-bit register as two 16-bit lanes packed in each 32-bit register (halves swapped on Rm) and applies the modulo (wrap-around) rule independently to every lane.

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

### Example 1 — Cross add/sub on packed halfwords

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SASX: cross add/sub on packed halfwords (used by complex-number kernels).
    movw    r1, #0x0005
    movt    r1, #0x0003
    movw    r2, #0x0002
    movt    r2, #0x0001
    sasx    r0, r1, r2          @ r0[hi]=r1[hi] + r2[lo], r0[lo]=r1[lo] − r2[hi]
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `sasx r0, r1, r2` exchanges the halves of `r2` first, then computes `r0[hi] = r1[hi] + r2[lo]` and `r0[lo] = r1[lo] − r2[hi]`.
3. `APSR.GE[3:2]` reflects the high-half result, `GE[1:0]` the low-half result.

### Example 2 — 2-point complex butterfly

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ One half of a 2-point complex butterfly with twiddle ±j applied.
    @ r1 packs (re_a hi, im_a lo); r2 packs (re_b hi, im_b lo).
    @ SASX yields (re_a + im_b, im_a − re_b) — the "+j·b added to a" lane pair.
    movw    r1, #0x0007              @ im_a =  7
    movt    r1, #0x0003              @ re_a =  3
    movw    r2, #0x0002              @ im_b =  2
    movt    r2, #0x0005              @ re_b =  5
    sasx    r0, r1, r2               @ r0[hi]=re_a + im_b = 5, r0[lo]=im_a − re_b = 2
loop:
    b   loop
```

**Walkthrough:**

1. Complex numbers are stored as packed (re, im) halfword pairs, one per 32-bit register.
2. Multiplying `b` by `+j` swaps re/im and negates the new imaginary part — exactly what `SASX`'s cross-pattern does.
3. The matching butterfly partner uses `SSAX` to get `(re_a − im_b, im_a + re_b)`. Together they replace ~6 scalar adds/subs and per-element loads.
4. `APSR.GE` carries per-lane sign info if a downstream rounding step uses `SEL`.

## See also

- [SADD8](SADD8.md) — same family
- [SADD16](SADD16.md) — same family
- [SSUB8](SSUB8.md) — same family
- [SSAX](SSAX.md) — mirror operation (subtract on hi, add on lo)
- [SEL](SEL.md) — consume the GE flags this instruction sets

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SASX*.
