# QSUB8 — signed saturating per-lane subtract of packed bytes

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
QSUB8 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `QSUB8` is the signed lane-wise saturating subtract on four packed bytes: ideal for *signed* pixel differences (motion-detection deltas where you actually want to keep the sign), four-channel 8-bit audio differencing, or computing per-lane error signals in a low-bit-depth DSP loop. Each lane independently clamps to `[−128, +127]`, so a runaway delta can't wrap a channel. Without `QSUB8` you'd `SXTB` each lane, scalar `QSUB`, re-pack — ~8 cycles versus 1.

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
        Rd<lane i> = SignedSat(x, 8)
```

`QSUB8` treats each 32-bit register as 4× 8-bit lanes packed in each 32-bit register and applies the signed saturating (clamps to lane range) rule independently to every lane.

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

### Example 1 — minimal packed-byte signed saturating subtract

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ QSUB8 demo: per-lane subtract on packed bytes.
    movw    r1, #0x3040
    movt    r1, #0x1020
    movw    r2, #0x0101
    movt    r2, #0x0101
    qsub8  r0, r1, r2          @ QSUB8: signed, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `qsub8 r0, r1, r2` treats each register as 4 packed byte lanes and subtracted them lane-by-lane.
3. Each lane is then **saturated** to the signed `8`-bit range — no wrap-around, but `APSR.Q` is **not** updated.

### Example 2 — signed pixel-row delta for motion detection

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Compute signed lane-wise differences of two 4-pixel rows (signed 8-bit).
    @ r0 = current row , r1 = previous row, both packed as 4 signed bytes.
    movw    r0, #0x4020
    movt    r0, #0x60F0         @ row N
    movw    r1, #0x3030
    movt    r1, #0x5010         @ row N-1
    qsub8   r2, r0, r1          @ signed lane-wise (curr - prev), each clamped
loop:
    b   loop
```

**Walkthrough:**

1. `r0` and `r1` carry four packed signed 8-bit pixel samples (e.g. high-pass filtered grayscale).
2. `qsub8` produces a signed delta per lane in one cycle; any lane whose difference would exceed `+127` or `−128` is clamped, so a single bright impulse can't poison the result.
3. The signed result is what feeds a sign-aware motion-direction estimator; the alternative (`SXTB` × 4 + scalar `QSUB` × 4 + repack) is ~8 cycles versus 1.

## See also

- [QADD8](QADD8.md) — same family
- [QADD16](QADD16.md) — same family
- [QSUB16](QSUB16.md) — same family
- [QADD](QADD.md) — scalar saturating add (this is the SIMD lane-wise version)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *QSUB8*.
