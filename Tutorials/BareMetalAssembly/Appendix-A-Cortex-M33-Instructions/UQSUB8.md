# UQSUB8 — unsigned saturating per-lane subtract of packed bytes

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UQSUB8 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `UQSUB8` is the saturating unsigned byte-wise subtract: each lane computes `max(0, a−b)` for free, because underflow clamps to zero rather than wrapping to 255. That makes it the natural primitive for byte-wise *positive* differences between two image rows (background subtraction, threshold-by-difference, contrast stretching), and for the front half of an SAD-style motion-detector before pairing with `UQSUB8` on the swapped operands. Without `UQSUB8` you'd need a per-lane compare-and-conditional-subtract or four `UXTB`/scalar/`STRB` sequences — ~8 cycles versus 1.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | `R0`–`R12`, `LR` (not `PC`/`SP`) |
| `<Rn>` | first source GPR | same constraints as `<Rd>` |
| `<Rm>` | second source GPR | same constraints as `<Rd>` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    for i in 0..3:
        x = UInt(Rn<lane i>) − UInt(Rm<lane i>)
        Rd<lane i> = UnsignedSat(x, 8)
```

`UQSUB8` treats each 32-bit register as 4× 8-bit lanes packed in each 32-bit register and applies the unsigned saturating (clamps to lane range) rule independently to every lane.

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

### Example 1 — minimal packed-byte unsigned saturating subtract

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ UQSUB8 demo: per-lane subtract on packed bytes.
    movw    r1, #0x3040
    movt    r1, #0x1020
    movw    r2, #0x0101
    movt    r2, #0x0101
    uqsub8  r0, r1, r2          @ UQSUB8: unsigned, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `uqsub8 r0, r1, r2` treats each register as 4 packed byte lanes and subtracted them lane-by-lane.
3. Each lane is then **saturated** to the unsigned `8`-bit range — no wrap-around, and `APSR.Q` is **not** updated.

### Example 2 — byte-wise saturating row difference between two image rows

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Compute |row_A - row_B| floored at 0 for four pixels per word.
    @ Pair this with a swapped-operand uqsub8 + uadd8 to get true |a-b|.
    movw    r0, #0x80FF         @ row A pixels: 0x80, 0xFF, ...
    movt    r0, #0x4020
    movw    r1, #0x6010         @ row B pixels
    movt    r1, #0x9050
    uqsub8  r2, r0, r1          @ each lane: max(0, A - B), no wrap to 0xFF
loop:
    b   loop
```

**Walkthrough:**

1. `r0` and `r1` each carry four unsigned 8-bit pixel intensities from corresponding rows.
2. `uqsub8` computes `max(0, A − B)` per lane in one cycle — underflow floors at zero rather than wrapping to `0xFF`, which is exactly what background-subtraction wants.
3. To get the symmetric absolute difference, do a second `uqsub8 r3, r1, r0` and OR the results — still 2 cycles for four pixels, versus ~10 cycles of scalar code with explicit `CMP`/conditional-subtract.

## See also

- [UQADD8](UQADD8.md) — same family
- [UQADD16](UQADD16.md) — same family
- [UQSUB16](UQSUB16.md) — same family
- [USAT](USAT.md) — scalar unsigned saturation

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *UQSUB8*.
