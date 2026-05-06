# QADD16 — signed saturating per-lane add of packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
QADD16 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `QADD16` adds two pairs of signed 16-bit lanes in parallel and clamps each independently. The classic case is a stereo audio mix-down: `L:R` packed into one register, another `L:R` into a second, one `qadd16` and you've mixed both channels with overflow protection in a single cycle. Also useful for pairwise sensor-channel sums (e.g. two 16-bit ADC readings packed together) or for the ±32767-clamped accumulator inside a fixed-point IIR. Without `QADD16` you'd `SXTH` each half, do two scalar `QADD`s, then re-pack with `PKHBT` — about 4–5 cycles instead of 1.

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
        Rd<lane i> = SignedSat(x, 16)
```

`QADD16` treats each 32-bit register as 2× 16-bit lanes packed in each 32-bit register and applies the signed saturating (clamps to lane range) rule independently to every lane.

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

### Example 1 — minimal packed-halfword signed saturating add

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ QADD16 demo: per-lane add on packed halfwords.
    movw    r1, #0x0200
    movt    r1, #0x1000
    movw    r2, #0x0002
    movt    r2, #0x0001
    qadd16  r0, r1, r2          @ QADD16: signed, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `qadd16 r0, r1, r2` treats each register as 2 packed halfword lanes and added them lane-by-lane.
3. Each lane is then **saturated** to the signed `16`-bit range — no wrap-around, but `APSR.Q` is **not** updated.

### Example 2 — stereo audio sample-pair mix-down

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Mix two stereo audio frames packed as L:R signed 16-bit halves.
    @ r0 = frame A: hi=L_A=+12000, lo=R_A=-8000
    @ r1 = frame B: hi=L_B=+25000, lo=R_B=+9000
    movw    r0, #0xE0C0         @ R_A = -8000 = 0xE0C0
    movt    r0, #0x2EE0         @ L_A = +12000 = 0x2EE0
    movw    r1, #0x2328         @ R_B = +9000 = 0x2328
    movt    r1, #0x61A8         @ L_B = +25000 = 0x61A8
    qadd16  r2, r0, r1          @ L_out = sat(L_A+L_B), R_out = sat(R_A+R_B)
loop:
    b   loop
```

**Walkthrough:**

1. Each register holds a complete stereo frame: high halfword is the left channel, low halfword is the right channel.
2. `qadd16` performs both signed 16-bit additions in parallel; here the left lane (`12000 + 25000 = 37000`) saturates to `+32767`, while the right lane (`−8000 + 9000 = +1000`) passes through cleanly.
3. The single instruction replaces what would otherwise be a `SXTH`-pair, two scalar `QADD`s, and a `PKHBT` to repack — about 5 cycles versus 1.

## See also

- [QADD8](QADD8.md) — same family
- [QSUB8](QSUB8.md) — same family
- [QSUB16](QSUB16.md) — same family
- [QADD](QADD.md) — scalar saturating add (this is the SIMD lane-wise version)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *QADD16*.
