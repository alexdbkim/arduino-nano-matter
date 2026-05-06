# SHSUB8 — signed halving per-lane subtract of packed bytes

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SHSUB8 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this**: `SHSUB8` is per-byte signed `(a − b)/2`, four lanes at a time — perfect for the "centered difference" pre-stage of a 1D Sobel/Prewitt edge filter on int8 imagery, or a Haar-step diff on packed mono audio. Halving means the worst-case `+127 − (−128) = +255` collapses to `+127`, fitting cleanly back in the byte. Without `SHSUB8` the equivalent is four sign-extends, four subs, four shifts, and a repack — about ten instructions reduced to one.

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
        x = SInt(Rn<lane i>) − SInt(Rm<lane i>)
        Rd<lane i> = (x >> 1)<7:0>     // arithmetic shift
```

`SHSUB8` treats each 32-bit register as 4× 8-bit lanes packed in each 32-bit register and applies the halving signed (result = (a±b) >> 1) rule independently to every lane.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never sets any flag. Halving guarantees the result fits, so there is nothing to report.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | Thumb-2 only — there is **no** 16-bit encoding |

There is no 16-bit Thumb encoding for this instruction; the assembler always emits the 32-bit form.

## Exceptions / faults

- (none) — register-to-register only, no memory access.

## Example

### Example 1 — Per-lane subtract on signed packed bytes

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SHSUB8 demo: per-lane subtract on packed bytes.
    movw    r1, #0x3040
    movt    r1, #0x1020
    movw    r2, #0x0101
    movt    r2, #0x0101
    shsub8  r0, r1, r2          @ SHSUB8: signed, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `shsub8 r0, r1, r2` treats each register as 4 packed byte lanes and subtracted them lane-by-lane.
3. Each lane result is **arithmetic-shifted right by 1** so the sum cannot overflow.

### Example 2 — Centered difference for int8 edge detection

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Pre-stage of a 1D edge filter: 4 packed int8 pixel differences in one cycle,
    @ each halved so the result still fits in a signed byte.
    movw    r1, #0x4060           @ p0=+0x60, p1=+0x40
    movt    r1, #0x2030           @ p2=+0x30, p3=+0x20
    movw    r2, #0xFE02           @ q0=+0x02, q1=-0x02
    movt    r2, #0xFC04           @ q2=+0x04, q3=-0x04
    shsub8  r0, r1, r2            @ r0[i] = (p[i] - q[i]) >> 1, signed lane-wise
loop:
    b       loop
```

**Walkthrough:**

1. `r1` is a 4-pixel int8 row; `r2` is its right-shifted neighbour, also int8.
2. `shsub8` performs `p[i] − q[i]` in 9-bit precision, then arithmetic-shifts each result right by 1.
3. Even when `p[i] = +127` and `q[i] = −128` (signed worst case), the intermediate `+255` is haved to `+127` — no `SSAT8`, no overflow trap, just a clean byte gradient ready for the next stage.

## See also

- [SHADD8](SHADD8.md) — same family
- [SHADD16](SHADD16.md) — same family
- [SHSUB16](SHSUB16.md) — same family
- [PKHBT](PKHBT.md) — rebuild a packed halfword pair after halving

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SHSUB8*.
