# UQSUB16 — unsigned saturating per-lane subtract of packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UQSUB16 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `UQSUB16` gives you two parallel unsigned 16-bit saturating subtracts where underflow floors at 0. Useful for pairwise *positive deltas* on 16-bit unsigned readings (two-channel histogram-diff, two-channel monotonic counter delta with no negative result, frame-to-frame brightness drop on packed 16-bit pixel pairs). Without `UQSUB16`, getting the same floor-zero behaviour on both lanes takes a `CMP`/`SUB`/`MOVCC #0` × 2 sequence or `UXTH`-and-scalar — ~5 cycles versus 1.

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
        Rd<lane i> = UnsignedSat(x, 16)
```

`UQSUB16` treats each 32-bit register as 2× 16-bit lanes packed in each 32-bit register and applies the unsigned saturating (clamps to lane range) rule independently to every lane.

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

### Example 1 — minimal packed-halfword unsigned saturating subtract

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ UQSUB16 demo: per-lane subtract on packed halfwords.
    movw    r1, #0x0200
    movt    r1, #0x1000
    movw    r2, #0x0002
    movt    r2, #0x0001
    uqsub16  r0, r1, r2          @ UQSUB16: unsigned, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `uqsub16 r0, r1, r2` treats each register as 2 packed halfword lanes and subtracted them lane-by-lane.
3. Each lane is then **saturated** to the unsigned `16`-bit range — no wrap-around, and `APSR.Q` is **not** updated.

### Example 2 — two-channel histogram-bin positive delta

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Two unsigned 16-bit counters packed (hi, lo). Compute positive delta
    @ vs. previous snapshot; underflow floors at 0 (counters can't go negative).
    movw    r0, #0x0500         @ lo = current bin A count
    movt    r0, #0x0800         @ hi = current bin B count
    movw    r1, #0x0480         @ lo = previous bin A count
    movt    r1, #0x0900         @ hi = previous bin B count (greater than current!)
    uqsub16 r2, r0, r1          @ hi clamps to 0, lo gets a real positive delta
loop:
    b   loop
```

**Walkthrough:**

1. Two 16-bit histogram counters live packed in `r0` (current) and `r1` (previous).
2. `uqsub16` produces both deltas in parallel; the high lane (`0x0800 − 0x0900`) would underflow, so it clamps to `0` — perfect for "report only growth" semantics.
3. The scalar equivalent needs `UXTH`-and-`CMP`-and-conditional-subtract per lane (~5 cycles) for what `uqsub16` does in 1.

## See also

- [UQADD8](UQADD8.md) — same family
- [UQADD16](UQADD16.md) — same family
- [UQSUB8](UQSUB8.md) — same family
- [USAT](USAT.md) — scalar unsigned saturation

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *UQSUB16*.
