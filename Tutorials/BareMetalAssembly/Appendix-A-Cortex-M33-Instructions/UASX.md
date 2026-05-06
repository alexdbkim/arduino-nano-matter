# UASX — unsigned wrap-around exchange-then-add-high/sub-low on packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UASX <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `UASX` is the unsigned, non-saturating sibling of `UQASX`. The cross pattern (`Rd[hi] = Rn[hi] + Rm[lo]`, `Rd[lo] = Rn[lo] − Rm[hi]`) is the shape behind FFT butterflies, complex multiplication, and 2D rotate-and-add transforms in graphics. As with the rest of the family, **`APSR.GE` is set per halfword lane** — top two bits for the high result (carry-out of the add), bottom two for the low (no-borrow of the sub) — so a `SEL` immediately after can blend lanes based on which one carried/borrowed. That `GE`+`SEL` pairing is what makes packed conditional operations cheap; without it you'd be issuing scalar compares and branches.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | `R0`–`R12`, `LR` (not `PC`/`SP`) |
| `<Rn>` | first source GPR | same constraints as `<Rd>` |
| `<Rm>` | second source GPR | same constraints as `<Rd>` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    h = UInt(Rn<31:16>) + UInt(Rm<15:0>)
    l = UInt(Rn<15:0>)  − UInt(Rm<31:16>)
    Rd<31:16> = h<15:0>
    Rd<15:0>  = l<15:0>
    APSR.GE<3:2> = lane_ok(h)
    APSR.GE<1:0> = lane_ok(l)
```

`UASX` treats each 32-bit register as two 16-bit lanes packed in each 32-bit register (halves swapped on Rm) and applies the modulo (wrap-around) rule independently to every lane.

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
    @ UASX: cross add/sub on packed halfwords (used by complex-number kernels).
    movw    r1, #0x0005
    movt    r1, #0x0003
    movw    r2, #0x0002
    movt    r2, #0x0001
    uasx    r0, r1, r2          @ r0[hi]=r1[hi] + r2[lo], r0[lo]=r1[lo] − r2[hi]
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `uasx r0, r1, r2` exchanges the halves of `r2` first, then computes `r0[hi] = r1[hi] + r2[lo]` and `r0[lo] = r1[lo] − r2[hi]`.
3. `APSR.GE[3:2]` reflects the high-half result, `GE[1:0]` the low-half result.

### Example 2 — 2D vector "rotate-and-add" step

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Graphics: combine a 2D vector (x,y) packed in r1 with deltas (dx,dy) packed in r2,
    @ producing (x+dy, y−dx) — one step of a small rotate-and-translate transform.
    movw    r1, #0x0040              @ y = 0x0040
    movt    r1, #0x0080              @ x = 0x0080
    movw    r2, #0x0003              @ dy = 3 (low half of r2)
    movt    r2, #0x0002              @ dx = 2 (high half of r2)
    uasx    r0, r1, r2               @ r0[hi]=x + dy = 0x0083, r0[lo]=y − dx = 0x003E
loop:
    b   loop
```

**Walkthrough:**

1. We pack a vector and its delta into halfword pairs so one SIMD op moves both components at once.
2. `UASX` swaps the halves of `r2` so `dy` is added to `x` (high lane) and `dx` is subtracted from `y` (low lane) — exactly the lane-cross you need for `+90°` rotation in 2D.
3. `APSR.GE` carries per-lane carry/borrow info: useful if a follow-up `SEL` swaps in a bounding-box clamp value when a coordinate wraps.

## See also

- [UADD8](UADD8.md) — same family
- [UADD16](UADD16.md) — same family
- [USUB8](USUB8.md) — same family
- [USAX](USAX.md) — mirror operation (subtract on hi, add on lo)
- [SEL](SEL.md) — consume the GE flags this instruction sets

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *UASX*.
