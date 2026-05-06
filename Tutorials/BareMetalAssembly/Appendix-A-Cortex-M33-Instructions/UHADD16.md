# UHADD16 — unsigned halving per-lane add of packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UHADD16 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this**: `UHADD16` averages two packed unsigned 16-bit values per cycle — directly useful for box-blurring 16-bit grayscale rows or downsample-by-2 of a `uint16` sensor stream (`y[n] = (x[2n] + x[2n+1])/2`). Because the halving is a logical right-shift on `(a + b)`, the carry that normally bumps a 16-bit unsigned add into 17 bits is absorbed harmlessly. Without `UHADD16` you'd `UXTH` both halves into 32-bit regs, `ADD`, `LSR #1`, repack via `PKHBT` — five-plus instructions where one suffices.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | `R0`–`R12`, `LR` (not `PC`/`SP`) |
| `<Rn>` | first source GPR | same constraints as `<Rd>` |
| `<Rm>` | second source GPR | same constraints as `<Rd>` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    for i in 0..1:
        x = UInt(Rn<lane i>) + UInt(Rm<lane i>)
        Rd<lane i> = (x >> 1)<15:0>     // logical shift
```

`UHADD16` treats each 32-bit register as 2× 16-bit lanes packed in each 32-bit register and applies the halving unsigned (result = (a±b) >> 1) rule independently to every lane.

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

### Example 1 — Per-lane add on unsigned packed halfwords

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ UHADD16 demo: per-lane add on packed halfwords.
    movw    r1, #0x0200
    movt    r1, #0x1000
    movw    r2, #0x0002
    movt    r2, #0x0001
    uhadd16  r0, r1, r2          @ UHADD16: unsigned, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `uhadd16 r0, r1, r2` treats each register as 2 packed halfword lanes and added them lane-by-lane.
3. Each lane result is **logical-shifted right by 1** so the sum cannot overflow.

### Example 2 — Box-blur row average on 16-bit grayscale

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Average two 16-bit grayscale pixel pairs from adjacent rows — one box-blur step.
    movw    r1, #0xC000           @ row0 px0 = 0xC000  (49152)
    movt    r1, #0xFFFF           @ row0 px1 = 0xFFFF  (max)
    movw    r2, #0x4000           @ row1 px0 = 0x4000  (16384)
    movt    r2, #0x0001           @ row1 px1 = 0x0001  (1)
    uhadd16 r0, r1, r2            @ r0[lo]=(0xC000+0x4000)/2, r0[hi]=(0xFFFF+0x0001)/2
loop:
    b       loop
```

**Walkthrough:**

1. `r1` and `r2` each hold two packed `uint16` pixels from neighbouring rows of an image.
2. `uhadd16` adds matched lanes in 17-bit precision, then logical-shifts each lane right by 1.
3. Lane 0 gives `0x8000`; lane 1 gives `0x8000` — both fit cleanly in a `uint16`. The carry from `0xFFFF + 0x0001 = 0x10000` is consumed by the built-in `>>1`, so no widening or post-clip is needed for an N-tap box-blur loop.

## See also

- [UHADD8](UHADD8.md) — same family
- [UHSUB8](UHSUB8.md) — same family
- [UHSUB16](UHSUB16.md) — same family
- [PKHBT](PKHBT.md) — rebuild a packed halfword pair after halving

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *UHADD16*.
