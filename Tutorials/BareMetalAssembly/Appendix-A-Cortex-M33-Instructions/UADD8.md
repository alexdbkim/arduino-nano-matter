# UADD8 — unsigned wrap-around per-lane add of packed bytes

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UADD8 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `UADD8` runs four unsigned byte-lane adds in one cycle, wrapping mod-256 (no saturation). Reach for it when overflow can't happen (small deltas, summing pre-clamped histogram bin quads) or when you actually want wrap-around (hash diffusion). **Each lane sets one `APSR.GE` bit on carry-out**, which `SEL` reads to do per-lane selection — the killer pattern that justifies all these modulo SIMD ops. Vectorized clamp-on-overflow, byte-wise max of two raster lines, and masked blends collapse from ~8 scalar instructions to two using `GE`+`SEL`.

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
        Rd<lane i> = x<7:0>             // wraps modulo 2^8
        APSR.GE<bits for lane i> = lane_ok(x)
```

`UADD8` treats each 32-bit register as 4× 8-bit lanes packed in each 32-bit register and applies the modulo (wrap-around) rule independently to every lane.

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

### Example 1 — Per-lane unsigned byte add

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ UADD8 demo: per-lane add on packed bytes.
    movw    r1, #0x3040
    movt    r1, #0x1020
    movw    r2, #0x0101
    movt    r2, #0x0101
    uadd8  r0, r1, r2          @ UADD8: unsigned, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `uadd8 r0, r1, r2` treats each register as 4 packed byte lanes and added them lane-by-lane.
3. `APSR.GE` bits flag the lanes whose unsigned add produced a carry-out.

### Example 2 — Sum two histogram bin quads in one cycle

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Merge 4 unsigned histogram-bin bytes from two streams.
    @ r1 = stream A's 4 bins, r2 = stream B's 4 bins.
    movw    r1, #0x0203
    movt    r1, #0x0405
    movw    r2, #0x0102
    movt    r2, #0x0304
    uadd8   r0, r1, r2          @ 4 unsigned byte adds; GE[i]=1 on lanes that overflowed
loop:
    b   loop
```

**Walkthrough:**

1. `uadd8` does four 8-bit unsigned bin merges per cycle — 4× the work of a scalar `add`.
2. `APSR.GE[i]` is set on every lane that carried out (true sum > 255). The result lane wrapped mod-256, so `GE` tells you exactly which bins to clamp.
3. A 2-instruction follow-up — `mvn rsat, #0` then `sel r0, rsat, r0` — would clamp every overflowed bin to `0xFF`, giving a poor-man's `UQADD8` that you control yourself.

## See also

- [UADD16](UADD16.md) — same family
- [USUB8](USUB8.md) — same family
- [USUB16](USUB16.md) — same family
- [SEL](SEL.md) — consume the GE flags this instruction sets

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *UADD8*.
