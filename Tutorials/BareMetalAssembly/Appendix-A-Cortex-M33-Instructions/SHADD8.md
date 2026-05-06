# SHADD8 — signed halving per-lane add of packed bytes

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SHADD8 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this**: `SHADD8` is a four-lane "average packed signed bytes" — exactly what a 1D box-blur on int8 audio or an int8 pixel-row mix needs. Each lane is `(a + b) >> 1` arithmetic-shifted *inside* the add, so the result cannot overflow even when both inputs are at +127 or both at −128. Without `SHADD8`, averaging two int8 vectors means four `SXTB`s, four `ADD`s, four `ASR #1`s, and a repack — about a dozen instructions vs. one cycle here.

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
        x = SInt(Rn<lane i>) + SInt(Rm<lane i>)
        Rd<lane i> = (x >> 1)<7:0>     // arithmetic shift
```

`SHADD8` treats each 32-bit register as 4× 8-bit lanes packed in each 32-bit register and applies the halving signed (result = (a±b) >> 1) rule independently to every lane.

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

### Example 1 — Per-lane add on signed packed bytes

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SHADD8 demo: per-lane add on packed bytes.
    movw    r1, #0x3040
    movt    r1, #0x1020
    movw    r2, #0x0101
    movt    r2, #0x0101
    shadd8  r0, r1, r2          @ SHADD8: signed, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `shadd8 r0, r1, r2` treats each register as 4 packed byte lanes and added them lane-by-lane.
3. Each lane result is **arithmetic-shifted right by 1** so the sum cannot overflow.

### Example 2 — 1D box-blur on a signed int8 sample line

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Average two int8 sample lines (4 samples per word) lane-wise without overflow.
    movw    r1, #0x4060           @ a0=+0x60, a1=+0x40
    movt    r1, #0x2030           @ a2=+0x30, a3=+0x20
    movw    r2, #0xC0E0           @ b0=-0x40, b1=-0x20
    movt    r2, #0xF0F8           @ b2=-0x10, b3=-0x08
    shadd8  r0, r1, r2            @ r0[i] = (a[i]+b[i]) >> 1, signed, lane-wise
loop:
    b       loop
```

**Walkthrough:**

1. Two packed int8 vectors live in `r1` and `r2`, four samples each.
2. `shadd8` adds matched lanes in 9-bit precision internally, then arithmetic-shifts each by 1.
3. Lane 0 computes `(+0x60 + −0x40)/2 = +0x10`; lane 3 computes `(+0x20 + −0x08)/2 = +0x0C`. The `>>1` guarantees every byte fits — even `+127 + +127` becomes `+127`.

## See also

- [SHADD16](SHADD16.md) — same family
- [SHSUB8](SHSUB8.md) — same family
- [SHSUB16](SHSUB16.md) — same family
- [PKHBT](PKHBT.md) — rebuild a packed halfword pair after halving

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SHADD8*.
