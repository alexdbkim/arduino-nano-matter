# SSUB8 — signed wrap-around per-lane subtract of packed bytes

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SSUB8 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `SSUB8` is most often run for its flag side-effect, not its result: `SSUB8 t, a, b; SEL r, a, b` collapses a 4-byte signed compare-and-select into two instructions. **One `APSR.GE` bit is written per byte lane, set when that lane's signed difference is `≥ 0`** — and `SEL` reads them to pick per-lane between `Rn` and `Rm`. That's how vectorized signed max/min/abs become two-op sequences; the scalar equivalent is ~10 instructions with branches. The mod-256 difference left in `Rd` is rarely the point — the per-lane GE flags are the killer feature.

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
        Rd<lane i> = x<7:0>             // wraps modulo 2^8
        APSR.GE<bits for lane i> = lane_ok(x)
```

`SSUB8` treats each 32-bit register as 4× 8-bit lanes packed in each 32-bit register and applies the modulo (wrap-around) rule independently to every lane.

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

### Example 1 — Per-lane signed byte subtract

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SSUB8 demo: per-lane subtract on packed bytes.
    movw    r1, #0x3040
    movt    r1, #0x1020
    movw    r2, #0x0101
    movt    r2, #0x0101
    ssub8  r0, r1, r2          @ SSUB8: signed, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `ssub8 r0, r1, r2` treats each register as 4 packed byte lanes and subtracted them lane-by-lane.
3. `APSR.GE` bits flag the lanes whose signed result is `≥ 0`.

### Example 2 — Vectorized abs of 4 signed bytes via SEL

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Vectorized abs() over 4 packed signed bytes in r1.
    @ Trick: compute (0 − r1) → r3, and SSUB8 sets GE per lane = (0 − lane ≥ 0) = (lane ≤ 0).
    @ Then SEL picks r3 (the negated lane) where lane ≤ 0, else picks the original.
    movw    r1, #0x05FE              @ lanes:  0xFE = -2,  0x05 = +5
    movt    r1, #0x7F80              @ lanes:  0x80 = -128, 0x7F = +127
    movs    r2, #0
    ssub8   r3, r2, r1               @ r3 = -r1 lane-wise; APSR.GE[i] = 1 when r1.lane ≤ 0
    sel     r0, r3, r1               @ r0.lane = (r1 ≤ 0) ? -r1 : r1   → |r1|
loop:
    b   loop
```

**Walkthrough:**

1. `r3 = 0 − r1` per byte — that's both the candidate "negated" value AND the source of per-lane GE flags.
2. For lane *i*, `APSR.GE[i]` is set iff `0 − r1.lane_i ≥ 0`, i.e. `r1.lane_i ≤ 0`.
3. `SEL r0, r3, r1` reads `GE[i]`: when set, output `r3.lane_i` (= negated, now positive); when clear, output the original. Result: `|r1|` byte-wise.
4. Two instructions replace ~10 scalar ones with 4 conditional branches. Note `0x80` (-128) negates back to `0x80` due to mod-256 wrap — a known quirk of two's-complement abs.

## See also

- [SADD8](SADD8.md) — same family
- [SADD16](SADD16.md) — same family
- [SSUB16](SSUB16.md) — same family
- [SEL](SEL.md) — consume the GE flags this instruction sets

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SSUB8*.
