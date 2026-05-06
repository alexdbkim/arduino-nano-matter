# SADD16 — signed wrap-around per-lane add of packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SADD16 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `SADD16` is the modulo (no-saturate) cousin of `QADD16`. Reach for it when you know the sum can't overflow (e.g., narrow-range sensor halfwords being summed into a wider accumulator) or when wrap-around is part of the algorithm (CRC mixing, hash mixing). The killer feature is that **it sets the four `APSR.GE` flags — one signal per halfword lane, duplicated into two GE bits each** — so the next instruction `SEL` can pick winners lane-by-lane. Without `GE`+`SEL`, things like vectorized abs, per-halfword min/max, or mask-merge each cost ~6–10 instructions; with them, two.

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
        x = SInt(Rn<lane i>) + SInt(Rm<lane i>)
        Rd<lane i> = x<15:0>             // wraps modulo 2^16
        APSR.GE<bits for lane i> = lane_ok(x)
```

`SADD16` treats each 32-bit register as 2× 16-bit lanes packed in each 32-bit register and applies the modulo (wrap-around) rule independently to every lane.

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

### Example 1 — Stereo audio mixer (per-lane int16 add)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Stereo audio mixer: add two int16 sample pairs (L,R) packed in r1, r2.
    movw    r1, #0x0456
    movt    r1, #0x1234
    movw    r2, #0x0100
    movt    r2, #0xffe0
    sadd16  r0, r1, r2          @ lane-wise int16 add; GE flags reflect each lane's sign
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `sadd16 r0, r1, r2` treats each register as 2 packed halfword lanes and added them lane-by-lane.
3. `APSR.GE` bits flag the lanes whose signed result is `≥ 0`.

### Example 2 — FFT butterfly add stage

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ One add-stage of an FFT radix-2 butterfly: t = a + b on packed halfwords.
    @ r1 = a (re=0x1234, im=0x0456), r2 = b (re=0x0100, im=0x0020).
    movw    r1, #0x0456
    movt    r1, #0x1234
    movw    r2, #0x0020
    movt    r2, #0x0100
    sadd16  r0, r1, r2          @ r0 = a + b lane-wise (re, im) — modulo wrap
loop:
    b   loop
```

**Walkthrough:**

1. `r1` and `r2` hold complex (re, im) pairs as packed signed halfwords.
2. `sadd16` produces the butterfly's "sum" output for both real and imaginary parts in one instruction.
3. Pair this with an `ssub16 r4, r1, r2` to get the matching "difference" output and the butterfly is complete.
4. `APSR.GE` reflects each lane's sign — handy if a downstream stage uses `SEL` for conditional rounding or rescaling.

## See also

- [SADD8](SADD8.md) — same family
- [SSUB8](SSUB8.md) — same family
- [SSUB16](SSUB16.md) — same family
- [SEL](SEL.md) — consume the GE flags this instruction sets

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SADD16*.
