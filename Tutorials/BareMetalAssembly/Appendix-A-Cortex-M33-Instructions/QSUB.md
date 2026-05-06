# QSUB — saturating signed 32-bit subtract

## Class & availability

- **Class:** Saturation (DSP arithmetic)
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
QSUB{<c>}{<q>} {<Rd>,} <Rm>, <Rn>
```

Computes `Rd = sat32(Rm − Rn)` as signed 32-bit values. Operand order is `Rm − Rn` (Rm is the minuend); easy to get backwards if you're used to AT&T-style "src, dst" assembly.

**When you'd actually use this**: computing `error = setpoint − measurement` in a PID loop, or `delta = sensor_now − sensor_prev` for a derivative term, when the two operands can sit at opposite extremes. Plain `SUB` would wrap — `INT32_MAX − INT32_MIN` becomes `−1`, which a controller would happily integrate as "we're already on target", catastrophically. `QSUB` clamps to `±INT32_MAX` instead, keeping the *sign* of the error correct so the loop still pushes the right way; the sticky `Q` flag tells the supervisor it happened. Without `QSUB`, you'd need an explicit overflow check on every difference, which costs branches in the inner loop. Note `Q` is invisible to ordinary `Bxx` branches: read it via `MRS r?, APSR` (bit 27), clear via `MSR APSR_nzcvq`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR. If omitted, `Rd = Rm`. |
| `<Rm>` | minuend | R0–R12, LR |
| `<Rn>` | subtrahend | R0–R12, LR |

## Operation (pseudocode)

```text
if ConditionPassed() then
    (result, sat) = SignedSatQ(SInt(R[m]) - SInt(R[n]), 32)
    R[d] = result<31:0>
    if sat then APSR.Q = '1'
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | ✓ |

`Q` is set when the true mathematical difference would overflow `int32`. **Q is sticky** — clear with `MSR APSR_nzcvq, Rn` (bit 27 = 0).

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `QSUB <Rd>, <Rm>, <Rn>` |

DSP-extension; 32-bit Thumb only.

## Exceptions / faults

- (none).

## Example

### Example 1 — control-loop error and INT_MIN negation

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Compute "error = setpoint − measurement" for a control loop
    @ without wrap when the two are at opposite extremes.
    ldr     r0, =0x7FFFFFFF     @ setpoint = INT32_MAX
    ldr     r1, =0x80000000     @ measurement = INT32_MIN
    qsub    r2, r0, r1          @ true diff = 2^32-1, saturates to +0x7FFFFFFF, Q=1

    @ "Negate without wrap" idiom for INT32_MIN.
    mov     r0, #0
    ldr     r1, =0x80000000
    qsub    r3, r0, r1          @ r3 = 0 − INT32_MIN → saturates to +0x7FFFFFFF
loop:
    b   loop
```

**Walkthrough:**

1. `qsub r2, r0, r1` — the mathematical answer is `2·INT32_MAX + 1`, far outside `int32`. `QSUB` clamps to `+INT32_MAX` and sets `Q` instead of wrapping to `−1` like a plain `SUB` would. Critical in PID controllers where a wrap would suddenly invert the sign of the error term.
2. `qsub r3, r0, r1` (`0 − INT32_MIN`) — the asymmetry of two's complement means the negation of `INT32_MIN` doesn't fit in `int32`. `QSUB` gives `+INT32_MAX` and latches `Q`. This is the safe alternative to `RSB r3, r1, #0` for fixed-point code.

### Example 2 — saturating sensor delta

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Two int32 sensor readings from opposite rails; compute a saturating delta.
    ldr     r0, =0x7FFFFF00     @ sensor_now  ≈ +full-scale
    ldr     r1, =0x80000100     @ sensor_prev ≈ −full-scale
    qsub    r2, r0, r1          @ true diff > +INT32_MAX → r2 = +INT32_MAX, Q=1

    @ A second pair that does fit — Q is sticky so it stays 1.
    ldr     r0, =0x00010000
    ldr     r1, =0x00008000
    qsub    r3, r0, r1          @ r3 = 0x00008000 (no clip)

    @ The ONLY way to find out whether anything saturated since boot:
    mrs     r4, apsr
    tst     r4, #(1 << 27)      @ Z=0 → saw a clip somewhere
    bic     r4, r4, #(1 << 27)
    msr     APSR_nzcvq, r4      @ drain Q
loop:
    b   loop
```

**Walkthrough:**

1. `qsub r2, r0, r1` — the mathematical difference is roughly `2·INT32_MAX`, far outside `int32`. Plain `SUB` would silently wrap to a tiny negative value, and a derivative-style controller would interpret "huge swing" as "no swing". `QSUB` clamps to `+INT32_MAX` and sets `Q`, preserving the sign of the change so downstream gain stages still react in the correct direction.
2. `qsub r3, r0, r1` — fits cleanly, no clip. But `Q` from the previous instruction is still latched; that's the part that bites people. `Q` is "any saturation since I last cleared it", not "the most recent op clipped".
3. `mrs … tst #(1<<27) … msr APSR_nzcvq` — the read-and-drain ritual. Because there's no `Bxx`-on-Q in Thumb, you must `MRS` the APSR into a GP register and `TST` bit 27 yourself.

## See also

- [QADD](QADD.md) — saturating signed 32-bit add
- [QDSUB](QDSUB.md) — saturating `Rm − sat(2·Rn)`
- [SSAT](SSAT.md) — clip a value to fewer than 32 bits
- [QSUB16](QSUB16.md) / [QSUB8](QSUB8.md) — saturating SIMD subtract

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.x — *QSUB*.
