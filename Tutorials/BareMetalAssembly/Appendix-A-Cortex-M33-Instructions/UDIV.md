# UDIV — unsigned 32-bit integer division

## Class & availability

- **Class:** Arithmetic (divide)
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UDIV{<cond>} {<Rd>,} <Rn>, <Rm>
```

`Rd = Rn / Rm`, treating both operands as unsigned. The result is truncated toward zero (which for unsigned is the same as floor).

**When you'd actually use this**: Hardware unsigned divide for runtime divisors — converting timer ticks to ms when the tick rate is read from a register, ratiometric scaling like ADC counts → mV (`counts * Vref / 4096`), and base conversion in formatters. Latency is 2–11 cycles, so when the divisor is a compile-time constant the compiler replaces UDIV with a multiply-by-reciprocal (1 cycle) — bear that in mind before reaching for UDIV in a hot loop you control. The divide-by-zero behaviour is configurable: with `SCB->CCR.DIV_0_TRP=0` (reset default) UDIV silently returns 0, which masks bugs. Set the bit early in startup if you'd rather get a UsageFault.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | quotient destination | `R0`–`R12` |
| `<Rn>` | dividend (unsigned) | `R0`–`R12` |
| `<Rm>` | divisor (unsigned) | `R0`–`R12` |

There is **no remainder output** — to compute `Rn % Rm` use the `UDIV` + [MLS](MLS.md) idiom (see example).

## Operation (pseudocode)

```text
if ConditionPassed() then
    if UInt(R[m]) == 0 then
        if SCB.CCR.DIV_0_TRP == '1' then
            UsageFault(DIVBYZERO)
        else
            R[d] = 0                // silent return of zero
    else
        R[d] = UInt(R[n]) DIV UInt(R[m])
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never. There is no flag-setting form.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `UDIV Rd, Rn, Rm` (32-bit only) |

Cortex-M33 implements UDIV in hardware; latency is 2–11 cycles depending on operand magnitude.

## Exceptions / faults

- **Divide-by-zero**: if `SCB->CCR.DIV_0_TRP = 1` (bit 4), `UDIV` (or `SDIV`) by zero raises a UsageFault with `CFSR.UFSR.DIVBYZERO = 1`. If the bit is **0** (the reset default), the instruction silently returns 0 in `Rd` — perfectly legal but a frequent source of "where did this 0 come from?" bugs. Set `DIV_0_TRP` early in startup if you want loud failures.
- (no other faults).

## Example

### Example 1 — divmod-by-7 and silent divide-by-zero

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ UDIV demo: divmod by 7 of an unsigned value
    movs    r0, #100            @ dividend
    movs    r1, #7              @ divisor
    udiv    r2, r0, r1          @ r2 = 100 / 7 = 14
    mls     r3, r2, r1, r0      @ r3 = 100 - 14*7 = 2  (the remainder)

    @ divide-by-zero behaviour (assuming default SCB.CCR.DIV_0_TRP=0)
    movs    r4, #0
    udiv    r5, r0, r4          @ r5 = 0  (silent, no fault)
loop:
    b       loop
```

**Walkthrough:**

1. `udiv r2, r0, r1` — straight integer divide.
2. `mls r3, r2, r1, r0` — the canonical "compute remainder from quotient" pattern: `rem = dividend − quotient*divisor`.
3. `udiv r5, r0, r4` — divide by zero. Without `DIV_0_TRP`, this just writes 0; with it set, control transfers to the UsageFault handler.

### Example 2 — ADC counts to millivolts (ratiometric scale)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global reset_handler
    .thumb_func
reset_handler:
    movs    r0, #200            @ raw ADC sample
    ldr     r1, =3300           @ Vref in mV
    mul     r2, r0, r1          @ counts * mV = 660000
    ldr     r3, =4096           @ ADC full-scale (12-bit)
    udiv    r4, r2, r3          @ r4 = 161 mV
loop:
    b       loop
```

**Walkthrough:**

1. `mul r2, r0, r1` widens the calculation: 200 × 3300 = 660 000 fits comfortably in 32 bits but already exceeds 16 bits, so doing the multiply *before* the divide preserves precision.
2. `udiv r4, r2, r3` — the only runtime divide in the sequence. With a constant 4096 the compiler would actually rewrite this as `lsr r4, r2, #12` (1 cycle); we use UDIV here to make the ratiometric formula explicit.
3. The full pipeline is mul + udiv = at most 12 cycles. For higher-rate sampling you'd hoist the constant divisor out by precomputing a Q-format reciprocal and using `UMULL` + a shift instead.

## See also

- [SDIV](SDIV.md) — signed divide; same divide-by-zero rules
- [MLS](MLS.md) — partner instruction for computing remainders
- [MUL](MUL.md) — to verify a quotient

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.225 — *UDIV*. Divide-by-zero behaviour: §B3.4 (CCR) / §B3.6 (UsageFault).
