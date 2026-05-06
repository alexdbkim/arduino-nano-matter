# SADD8 — signed wrap-around per-lane add of packed bytes

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SADD8 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `SADD8` runs four byte-lane signed adds in one cycle, wrapping mod-256 instead of saturating like `QADD8`. Use it when overflow is impossible by construction (small audio deltas, packed running offsets summed into wider accumulators) or when wrap is part of the math (CRC mixing, hash diffusion). Critically, **it writes one `APSR.GE` bit per byte lane** based on each lane's signed result, and `SEL` reads exactly those bits to do per-lane selection. That `GE`+`SEL` pairing is the whole reason these modulo SIMD ops exist: vectorized abs, byte-wise min/max, and masked blend collapse from ~6–10 scalar instructions to two.

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
        x = SInt(Rn<lane i>) + SInt(Rm<lane i>)
        Rd<lane i> = x<7:0>             // wraps modulo 2^8
        APSR.GE<bits for lane i> = lane_ok(x)
```

`SADD8` treats each 32-bit register as 4× 8-bit lanes packed in each 32-bit register and applies the modulo (wrap-around) rule independently to every lane.

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

### Example 1 — Per-lane signed byte add demo

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SADD8 demo: per-lane add on packed bytes.
    movw    r1, #0x3040
    movt    r1, #0x1020
    movw    r2, #0x0101
    movt    r2, #0x0101
    sadd8  r0, r1, r2          @ SADD8: signed, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `sadd8 r0, r1, r2` treats each register as 4 packed byte lanes and added them lane-by-lane.
3. `APSR.GE` bits flag the lanes whose signed result is `≥ 0`.

### Example 2 — Mix two 4-channel int8 audio packets

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Add two 4-channel int8 audio packets (e.g. quad-mic capture) packed in one word each.
    movw    r1, #0x05F0          @ ch0=0xF0(-16), ch1=0x05(+5)
    movt    r1, #0x2010          @ ch2=0x10(+16), ch3=0x20(+32)
    movw    r2, #0x0102          @ ch0=+2, ch1=+1
    movt    r2, #0x10F0          @ ch2=-16, ch3=+16
    sadd8   r0, r1, r2           @ 4 signed byte adds; GE = per-lane sign of result
loop:
    b   loop
```

**Walkthrough:**

1. Each register packs 4 signed int8 audio samples (one per channel).
2. `sadd8` mixes both packets channel-by-channel in a single cycle — 4× the throughput of scalar `add`.
3. `APSR.GE[0..3]` is set on lanes whose mixed sample stayed `≥ 0`. A follow-up `SEL` could substitute zeros (silence) on any lane that went negative, for a vectorized half-wave rectifier in two ops.

## See also

- [SADD16](SADD16.md) — same family
- [SSUB8](SSUB8.md) — same family
- [SSUB16](SSUB16.md) — same family
- [SEL](SEL.md) — consume the GE flags this instruction sets

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SADD8*.
