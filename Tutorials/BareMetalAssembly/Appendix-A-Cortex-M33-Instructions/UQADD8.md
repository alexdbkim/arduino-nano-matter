# UQADD8 — unsigned saturating per-lane add of packed bytes

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UQADD8 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `UQADD8` is the workhorse for *unsigned* packed-byte saturation. The textbook example is RGBA pixel arithmetic: brighten a pixel by adding a constant tint to all four channels in one shot, or alpha-compose two pre-multiplied colours, with the per-channel ceiling of 255 enforced automatically. Equally good for 4-channel 8-bit accumulators (e.g. histogram buckets in a 32-bit word) where you must never wrap past 0xFF. Without `UQADD8`, an 8-bit RGBA blend with saturation needs four separate `UXTB` / `UQADD` / `STRB` sequences — about 8 cycles instead of 1.

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
        Rd<lane i> = UnsignedSat(x, 8)
```

`UQADD8` treats each 32-bit register as 4× 8-bit lanes packed in each 32-bit register and applies the unsigned saturating (clamps to lane range) rule independently to every lane.

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

### Example 1 — minimal packed-byte unsigned saturating add

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ UQADD8 demo: per-lane add on packed bytes.
    movw    r1, #0x3040
    movt    r1, #0x1020
    movw    r2, #0x0101
    movt    r2, #0x0101
    uqadd8  r0, r1, r2          @ UQADD8: unsigned, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `uqadd8 r0, r1, r2` treats each register as 4 packed byte lanes and added them lane-by-lane.
3. Each lane is then **saturated** to the unsigned `8`-bit range — no wrap-around, and `APSR.Q` is **not** updated.

### Example 2 — RGBA pixel saturating brighten

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Saturating add of two RGBA pixels (R,G,B,A packed as 4 unsigned bytes).
    @ r0 = pixel       (e.g. 0xFF80C040 -> A=0xFF, R=0x80, G=0xC0, B=0x40)
    @ r1 = brighten dt (e.g. 0x00404040 -> add +0x40 to R,G,B; alpha untouched)
    movw    r0, #0xC040
    movt    r0, #0xFF80
    movw    r1, #0x4040
    movt    r1, #0x0040
    uqadd8  r2, r0, r1          @ each channel clamps at 0xFF, no wrap
loop:
    b   loop
```

**Walkthrough:**

1. `r0` holds an RGBA pixel as four unsigned bytes; `r1` is a per-channel additive tint.
2. `uqadd8` adds all four channels in one cycle, each clamped at `0xFF`, so a near-white pixel can't wrap to dark when overdriven.
3. The non-SIMD path (`UXTB` × 4 + scalar `UQADD` × 4 + repack) costs ~8 cycles for what `uqadd8` does in 1 — meaningful when shading a whole framebuffer.

## See also

- [UQADD16](UQADD16.md) — same family
- [UQSUB8](UQSUB8.md) — same family
- [UQSUB16](UQSUB16.md) — same family
- [USAT](USAT.md) — scalar unsigned saturation

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *UQADD8*.
