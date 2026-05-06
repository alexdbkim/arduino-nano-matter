# SSAX — signed wrap-around exchange-then-sub-high/add-low on packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SSAX <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `SSAX` is the mirror of `SASX`: subtract the high lane, add the low lane (with `Rm`'s halves swapped). It's the other half of the FFT butterfly / complex-multiply pair (`(a−d, b+c)`) and shows up in 2D rotation kernels too. As with the rest of the family, the result wraps modulo 2^16 — no saturation — and **`APSR.GE` is updated per halfword lane** (top two bits = high result, bottom two = low), so a `SEL` afterwards can blend or pick per-lane. The `GE`+`SEL` combo is what makes vectorized min/max/abs cheap; without it you'd be doing scalar compares and branching, which costs roughly 4× the instructions.

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
    Rd<31:16> = h<15:0>
    Rd<15:0>  = l<15:0>
    APSR.GE<3:2> = lane_ok(h)
    APSR.GE<1:0> = lane_ok(l)
```

`SSAX` treats each 32-bit register as two 16-bit lanes packed in each 32-bit register (halves swapped on Rm) and applies the modulo (wrap-around) rule independently to every lane.

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
    @ SSAX: reverse-cross sub/add on packed halfwords.
    movw    r1, #0x0005
    movt    r1, #0x0003
    movw    r2, #0x0002
    movt    r2, #0x0001
    ssax    r0, r1, r2          @ r0[hi]=r1[hi] − r2[lo], r0[lo]=r1[lo] + r2[hi]
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `ssax r0, r1, r2` exchanges the halves of `r2` first, then computes `r0[hi] = r1[hi] − r2[lo]` and `r0[lo] = r1[lo] + r2[hi]`.
3. `APSR.GE[3:2]` reflects the high-half result, `GE[1:0]` the low-half result.

### Example 2 — Complex-multiply companion to SASX

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Companion to SASX in a complex-multiply / butterfly pair.
    @ With r1=(re_a, im_a) and r2=(re_b, im_b), SSAX yields (re_a − im_b, im_a + re_b)
    @ — i.e. the "−j·b added to a" lane pair.
    movw    r1, #0x0007              @ im_a = 7
    movt    r1, #0x0003              @ re_a = 3
    movw    r2, #0x0002              @ im_b = 2
    movt    r2, #0x0005              @ re_b = 5
    ssax    r0, r1, r2               @ r0[hi]=re_a − im_b = 1, r0[lo]=im_a + re_b = 12
loop:
    b   loop
```

**Walkthrough:**

1. `SSAX` performs the lane swap on `r2` then computes the high-minus, low-plus combination.
2. Together with `SASX` you get both halves of a radix-2 complex butterfly in two instructions instead of six scalar ops.
3. `APSR.GE` is set on the lanes whose signed result stayed `≥ 0`, so a downstream `SEL` can mux between alternative branches of the butterfly without a conditional jump.

## See also

- [SADD8](SADD8.md) — same family
- [SADD16](SADD16.md) — same family
- [SSUB8](SSUB8.md) — same family
- [SASX](SASX.md) — mirror operation (add on hi, subtract on lo)
- [SEL](SEL.md) — consume the GE flags this instruction sets

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SSAX*.
