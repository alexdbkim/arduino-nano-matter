# UHSUB16 — unsigned halving per-lane subtract of packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UHSUB16 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this**: `UHSUB16` produces `(a − b) / 2` per unsigned 16-bit lane — perfect for inter-frame motion deltas in 16-bit video, or for the diff stage of a 16-bit Haar wavelet. The halving guarantees the result stays inside 16 bits, even when the difference would otherwise be `0xFFFF` (which becomes `0x7FFF`). When `b > a`, the `(a − b)` is taken modulo 2¹⁶ and then logically halved — useful when you want a wrapped/signed-magnitude delta in one cycle. Without `UHSUB16` you'd `UXTH`, sub into 32 bits, `LSR #1`, and repack — multiple instructions for what `UHSUB16` does in one.

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
        x = UInt(Rn<lane i>) − UInt(Rm<lane i>)
        Rd<lane i> = (x >> 1)<15:0>     // logical shift
```

`UHSUB16` treats each 32-bit register as 2× 16-bit lanes packed in each 32-bit register and applies the halving unsigned (result = (a±b) >> 1) rule independently to every lane.

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

### Example 1 — Per-lane subtract on unsigned packed halfwords

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ UHSUB16 demo: per-lane subtract on packed halfwords.
    movw    r1, #0x0200
    movt    r1, #0x1000
    movw    r2, #0x0002
    movt    r2, #0x0001
    uhsub16  r0, r1, r2          @ UHSUB16: unsigned, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `uhsub16 r0, r1, r2` treats each register as 2 packed halfword lanes and subtracted them lane-by-lane.
3. Each lane result is **logical-shifted right by 1** so the sum cannot overflow.

### Example 2 — Frame-to-frame motion delta on uint16 pixels

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Inter-frame delta for two packed uint16 pixel pairs, halved to fit back in 16 bits.
    movw    r1, #0x9000           @ frame_t  px_lo = 0x9000
    movt    r1, #0xFFFF           @ frame_t  px_hi = 0xFFFF
    movw    r2, #0x4000           @ frame_t-1 px_lo = 0x4000
    movt    r2, #0x0FFF           @ frame_t-1 px_hi = 0x0FFF
    uhsub16 r0, r1, r2            @ r0[lo]=(0x9000-0x4000)/2, r0[hi]=(0xFFFF-0x0FFF)/2
loop:
    b       loop
```

**Walkthrough:**

1. `r1` is the current 16-bit frame, `r2` the previous frame, both with two packed pixels per word.
2. `uhsub16` subtracts in 17-bit unsigned precision, then logical-shifts each lane right by 1.
3. The hi-lane delta `0xFFFF − 0x0FFF = 0xF000` halves cleanly to `0x7800`, fitting in `uint16`. The result is a ready-to-store difference image with no `USAT` and no widening pass.

## See also

- [UHADD8](UHADD8.md) — same family
- [UHADD16](UHADD16.md) — same family
- [UHSUB8](UHSUB8.md) — same family
- [PKHBT](PKHBT.md) — rebuild a packed halfword pair after halving

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *UHSUB16*.
