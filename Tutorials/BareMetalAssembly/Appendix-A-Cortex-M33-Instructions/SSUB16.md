# SSUB16 — signed wrap-around per-lane subtract of packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SSUB16 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — The killer use of `SSUB16` is **per-lane signed compare**: `SSUB16 t, a, b; SEL r, a, b` gives you a vectorized signed max (or min, by swapping operands to `SEL`) on two packed halfwords in just two instructions. **`APSR.GE[3:2]` is set when the high lane's signed difference is `≥ 0`, and `GE[1:0]` likewise for the low lane** — and `SEL` reads exactly those bits to mux per-lane between `Rn` and `Rm`. Without `GE`+`SEL`, the same compare-and-select runs ~8 scalar instructions with branches. The mod-2^16 difference written to `Rd` is usually a side-effect; the flags are the point.

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
        Rd<lane i> = x<15:0>             // wraps modulo 2^16
        APSR.GE<bits for lane i> = lane_ok(x)
```

`SSUB16` treats each 32-bit register as 2× 16-bit lanes packed in each 32-bit register and applies the modulo (wrap-around) rule independently to every lane.

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

### Example 1 — Per-lane signed halfword subtract

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SSUB16 demo: per-lane subtract on packed halfwords.
    movw    r1, #0x0200
    movt    r1, #0x1000
    movw    r2, #0x0002
    movt    r2, #0x0001
    ssub16  r0, r1, r2          @ SSUB16: signed, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `ssub16 r0, r1, r2` treats each register as 2 packed halfword lanes and subtracted them lane-by-lane.
3. `APSR.GE` bits flag the lanes whose signed result is `≥ 0`.

### Example 2 — Vector signed max via SSUB16 + SEL

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Signed packed max of two int16 lanes via SSUB16 + SEL.
    @ For each lane: GE := (Rn − Rm ≥ 0) → SEL picks Rn, else Rm.
    movw    r1, #0x0100              @ a.lo =  +256
    movt    r1, #0xFFF0              @ a.hi =  -16
    movw    r2, #0x00FF              @ b.lo =  +255
    movt    r2, #0x0001              @ b.hi =  +1
    ssub16  r3, r1, r2               @ r3 discarded; APSR.GE per lane = sign(a − b) ≥ 0
    sel     r0, r1, r2               @ r0[lane] = (a ≥ b) ? a : b  → packed signed max
loop:
    b   loop
```

**Walkthrough:**

1. `SSUB16` computes `a − b` lane-wise. We don't care about `r3` — only the `APSR.GE` flags it produced.
2. For each halfword lane, `GE` is set if the signed difference was `≥ 0`, i.e. `a ≥ b`.
3. `SEL` reads `GE[3:2]` to pick `r1`'s high half vs `r2`'s, and `GE[1:0]` for the low half — yielding the packed signed maximum in `r0`.
4. Swap the source order to `sel r0, r2, r1` to get min instead. The whole compare-and-select takes 2 instructions instead of ~8 scalar ones.

## See also

- [SADD8](SADD8.md) — same family
- [SADD16](SADD16.md) — same family
- [SSUB8](SSUB8.md) — same family
- [SEL](SEL.md) — consume the GE flags this instruction sets

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SSUB16*.
