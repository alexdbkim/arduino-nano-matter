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

## See also

- [QADD](QADD.md) — saturating signed 32-bit add
- [QDSUB](QDSUB.md) — saturating `Rm − sat(2·Rn)`
- [SSAT](SSAT.md) — clip a value to fewer than 32 bits
- [QSUB16](QSUB16.md) / [QSUB8](QSUB8.md) — saturating SIMD subtract

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.x — *QSUB*.
