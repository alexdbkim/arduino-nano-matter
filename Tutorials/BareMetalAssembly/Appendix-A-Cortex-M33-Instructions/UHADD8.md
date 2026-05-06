# UHADD8 — unsigned halving per-lane add of packed bytes

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UHADD8 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this**: `UHADD8` is the headline pixel-averaging instruction: blend two RGBA quads in one cycle, per-channel, with no overflow ever (`0xFF + 0xFF = 0x1FF`, and the built-in `>>1` keeps it at `0xFF`). It's the 2×2 box-filter primitive — apply it twice across rows, twice across columns, and you have bilinear filtering. Without `UHADD8` you'd reach for `UXTB16` twice, `ADD`, `LSR #1`, `ORR` to repack — five instructions and an extra register; `UHADD8` is one cycle and zero scratch.

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
        x = UInt(Rn<lane i>) + UInt(Rm<lane i>)
        Rd<lane i> = (x >> 1)<7:0>     // logical shift
```

`UHADD8` treats each 32-bit register as 4× 8-bit lanes packed in each 32-bit register and applies the halving unsigned (result = (a±b) >> 1) rule independently to every lane.

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

### Example 1 — Per-lane add on unsigned packed bytes

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ UHADD8 demo: per-lane add on packed bytes.
    movw    r1, #0x3040
    movt    r1, #0x1020
    movw    r2, #0x0101
    movt    r2, #0x0101
    uhadd8  r0, r1, r2          @ UHADD8: unsigned, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `uhadd8 r0, r1, r2` treats each register as 4 packed byte lanes and added them lane-by-lane.
3. Each lane result is **logical-shifted right by 1** so the sum cannot overflow.

### Example 2 — Blending two RGBA pixels in one cycle

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Average two RGBA8888 pixels channel-by-channel in a single instruction.
    @ Layout: byte0=R, byte1=G, byte2=B, byte3=A.
    movw    r1, #0x80FF           @ pixel A: R=0xFF, G=0x80
    movt    r1, #0x4020           @           B=0x20, A=0x40
    movw    r2, #0x0040           @ pixel B: R=0x40, G=0x00
    movt    r2, #0xC0FF           @           B=0xFF, A=0xC0
    uhadd8  r0, r1, r2            @ r0 = blended RGBA = (A+B)/2 per channel
loop:
    b       loop
```

**Walkthrough:**

1. Two 32-bit packed RGBA pixels live in `r1` and `r2`, one byte per channel.
2. `uhadd8` adds matched bytes in 9-bit precision, then logical-shifts each lane right by 1.
3. Worst-case channel `0xFF + 0xFF` would otherwise be `0x1FF`, but the built-in `>>1` produces `0xFF` — never overflows the byte. The result is an exact per-channel midpoint, the building block for 2×2 bilinear filtering.

## See also

- [UHADD16](UHADD16.md) — same family
- [UHSUB8](UHSUB8.md) — same family
- [UHSUB16](UHSUB16.md) — same family
- [PKHBT](PKHBT.md) — rebuild a packed halfword pair after halving

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *UHADD8*.
