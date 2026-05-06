# QADD8 — signed saturating per-lane add of packed bytes

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
QADD8 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `QADD8` is the one-cycle answer when you have *four* signed 8-bit values packed into a 32-bit word and want to add a second packed quad lane-by-lane with clamping. Real DSP cases: a 4-channel 8-bit audio mixer, a vector-of-bytes accumulator that mustn't wrap (e.g. signed gradient fields in a tiny vision pipeline), or running totals over packed signed deltas. Without `QADD8`, the same job requires four `SXTB` / scalar `QADD` / `STRB` sequences — roughly 8–12 cycles versus the one cycle the SIMD form pays.

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
        Rd<lane i> = SignedSat(x, 8)
```

`QADD8` treats each 32-bit register as 4× 8-bit lanes packed in each 32-bit register and applies the signed saturating (clamps to lane range) rule independently to every lane.

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

### Example 1 — minimal packed-byte signed saturating add

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ QADD8 demo: per-lane add on packed bytes.
    movw    r1, #0x3040
    movt    r1, #0x1020
    movw    r2, #0x0101
    movt    r2, #0x0101
    qadd8  r0, r1, r2          @ QADD8: signed, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `qadd8 r0, r1, r2` treats each register as 4 packed byte lanes and added them lane-by-lane.
3. Each lane is then **saturated** to the signed `8`-bit range — no wrap-around, but `APSR.Q` is **not** updated.

### Example 2 — four-channel signed audio frame mix

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Mix two packed signed audio frames (4 mono samples per word).
    @ r0 = sample frame A : { +120, -100, +50, -10 }   bytes hi..lo
    @ r1 = sample frame B : {  +20,  +30, +60, -20 }
    movw    r0, #0x320A         @ low half:  0x32 = +50, 0x0A wraps -> use proper bytes
    movt    r0, #0x789C         @ high half: 0x78 = +120, 0x9C = -100 (signed)
    movw    r1, #0x3CEC         @ 0x3C = +60, 0xEC = -20
    movt    r1, #0x141E         @ 0x14 = +20, 0x1E = +30
    qadd8   r2, r0, r1          @ four signed 8-bit adds, each clamped to [-128,+127]
loop:
    b   loop
```

**Walkthrough:**

1. `r0` and `r1` each carry four packed signed 8-bit audio samples.
2. `qadd8` adds them lane-by-lane in one cycle; any lane that would exceed `+127` saturates to `+127`, any lane that would go below `−128` saturates to `−128`.
3. Doing the equivalent without SIMD would cost four `SXTB`/`QADD`/`STRB` sequences plus repacking — roughly 8–12 cycles for what `qadd8` does in 1.

## See also

- [QADD16](QADD16.md) — same family
- [QSUB8](QSUB8.md) — same family
- [QSUB16](QSUB16.md) — same family
- [QADD](QADD.md) — scalar saturating add (this is the SIMD lane-wise version)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *QADD8*.
