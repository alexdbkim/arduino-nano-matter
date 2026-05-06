# UADD16 — unsigned wrap-around per-lane add of packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UADD16 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `UADD16` adds two pairs of unsigned 16-bit lanes with wrap-around (no saturation). Reach for it when overflow can't happen by construction (e.g., summing 12-bit ADC samples or two histogram bin pairs into 16-bit accumulators) or when wrap is intentional (rolling counters, hash mixing). **The instruction writes `APSR.GE` per lane — set when the unsigned add carried out**, i.e. the true sum exceeded 0xFFFF. A follow-up `SEL` can then conditionally substitute lanes that overflowed (clamp, fall back, etc.). Without `GE`+`SEL` the same logic is ~6 scalar instructions with branches; with them, two.

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
        Rd<lane i> = x<15:0>             // wraps modulo 2^16
        APSR.GE<bits for lane i> = lane_ok(x)
```

`UADD16` treats each 32-bit register as 2× 16-bit lanes packed in each 32-bit register and applies the modulo (wrap-around) rule independently to every lane.

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

### Example 1 — Per-lane unsigned halfword add

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ UADD16 demo: per-lane add on packed halfwords.
    movw    r1, #0x0200
    movt    r1, #0x1000
    movw    r2, #0x0002
    movt    r2, #0x0001
    uadd16  r0, r1, r2          @ UADD16: unsigned, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `uadd16 r0, r1, r2` treats each register as 2 packed halfword lanes and added them lane-by-lane.
3. `APSR.GE` bits flag the lanes whose unsigned add produced a carry-out.

### Example 2 — Sum two histogram bin pairs

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Merge two streaming histograms by summing two bin-pairs at once.
    @ r1 packs (bin1_hi, bin1_lo) for stream A; r2 the same for stream B.
    movw    r1, #0x1234              @ A.bin_lo
    movt    r1, #0x0007              @ A.bin_hi
    movw    r2, #0x0010              @ B.bin_lo
    movt    r2, #0x0001              @ B.bin_hi
    uadd16  r0, r1, r2               @ r0 = (A+B) per bin; GE=1 on lanes that wrapped past 0xFFFF
loop:
    b   loop
```

**Walkthrough:**

1. Each register holds two adjacent histogram bins as packed unsigned halfwords.
2. `uadd16` merges both bins from streams A and B in one cycle — twice the throughput of a scalar `add` per bin.
3. `APSR.GE[3:2]` and `GE[1:0]` are set on lanes that overflowed `0xFFFF`. A follow-up `sel r0, rsat, r0` (with `rsat = 0xFFFFFFFF`) would clamp the wrapped lanes to max — a vectorized saturating-merge in three instructions.

## See also

- [UADD8](UADD8.md) — same family
- [USUB8](USUB8.md) — same family
- [USUB16](USUB16.md) — same family
- [SEL](SEL.md) — consume the GE flags this instruction sets

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *UADD16*.
