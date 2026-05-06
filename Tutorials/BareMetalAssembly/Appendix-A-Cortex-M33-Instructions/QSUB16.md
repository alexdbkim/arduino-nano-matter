# QSUB16 — signed saturating per-lane subtract of packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
QSUB16 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `QSUB16` does two parallel signed 16-bit saturating subtracts, the natural primitive for stereo sample-pair deltas (e.g. the `L−R` half of a mid-side decoder), pairwise signed sensor deltas, or a 16-bit per-lane error term in a fixed-point control loop. Both lanes clamp to `[−32768, +32767]` so a transient overshoot can't flip sign. The non-SIMD alternative (`SXTH` × 2, scalar `QSUB` × 2, `PKHBT`) costs ~5 cycles for the work `qsub16` does in 1.

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
        x = SInt(Rn<lane i>) − SInt(Rm<lane i>)
        Rd<lane i> = SignedSat(x, 16)
```

`QSUB16` treats each 32-bit register as 2× 16-bit lanes packed in each 32-bit register and applies the signed saturating (clamps to lane range) rule independently to every lane.

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

### Example 1 — minimal packed-halfword signed saturating subtract

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ QSUB16 demo: per-lane subtract on packed halfwords.
    movw    r1, #0x0200
    movt    r1, #0x1000
    movw    r2, #0x0002
    movt    r2, #0x0001
    qsub16  r0, r1, r2          @ QSUB16: signed, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `qsub16 r0, r1, r2` treats each register as 2 packed halfword lanes and subtracted them lane-by-lane.
3. Each lane is then **saturated** to the signed `16`-bit range — no wrap-around, but `APSR.Q` is **not** updated.

### Example 2 — stereo mid-side L−R extraction

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Compute the (L - R) "side" half of a mid-side stereo encoder using
    @ packed signed 16-bit halves: hi = L, lo = R, in r0; r1 carries R duplicated.
    movw    r0, #0xF000         @ R = -4096
    movt    r0, #0x4000         @ L = +16384
    movw    r1, #0xF000         @ lo lane: also R = -4096
    movt    r1, #0xF000         @ hi lane: R again, to subtract from L
    qsub16  r2, r0, r1          @ hi = sat(L - R), lo = sat(R - R) = 0
loop:
    b   loop
```

**Walkthrough:**

1. The "side" channel of mid-side stereo is `S = L − R`; placing `R` in both halves of `r1` lets `qsub16` produce `L − R` in one lane and a sanity-zero in the other.
2. `qsub16` performs both signed 16-bit subtractions in parallel and clamps each to `[−32768, +32767]`.
3. Without `qsub16` the same operation costs `SXTH` × 2, two scalar `QSUB`s, and a `PKHBT` repack — about 5 cycles versus 1.

## See also

- [QADD8](QADD8.md) — same family
- [QADD16](QADD16.md) — same family
- [QSUB8](QSUB8.md) — same family
- [QADD](QADD.md) — scalar saturating add (this is the SIMD lane-wise version)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *QSUB16*.
