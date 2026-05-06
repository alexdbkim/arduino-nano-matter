# SDIV — signed 32-bit integer division

## Class & availability

- **Class:** Arithmetic (divide)
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SDIV{<cond>} {<Rd>,} <Rn>, <Rm>
```

`Rd = Rn / Rm`, treating both operands as signed. The result is truncated **toward zero** (C99 `/` semantics, *not* floor): `−7 / 2 = −3`, not `−4`.

**When you'd actually use this**: Hardware signed integer division for cases the compiler can't precompute — runtime ratios with a non-constant divisor (e.g. converting cycles to ms when the rate is read from a register at boot), normalising signed sensor data, or implementing `printf("%d")`. SDIV takes 2–11 cycles depending on operand magnitude, so for a *constant* divisor compilers prefer the multiply-by-magic-reciprocal trick (1-cycle MUL + a shift) over SDIV. Two gotchas: it rounds toward zero (`-7 / 2 = -3`, not `-4`); and `SDIV(INT32_MIN, -1)` silently returns `INT32_MIN` instead of trapping. Pair with `MLS` to also recover a remainder — there is no SDIVMOD instruction.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | quotient destination | `R0`–`R12` |
| `<Rn>` | dividend (signed) | `R0`–`R12` |
| `<Rm>` | divisor (signed) | `R0`–`R12` |

No remainder output — compute it with `SDIV` + [MLS](MLS.md).

## Operation (pseudocode)

```text
if ConditionPassed() then
    if SInt(R[m]) == 0 then
        if SCB.CCR.DIV_0_TRP == '1' then
            UsageFault(DIVBYZERO)
        else
            R[d] = 0
    else
        R[d] = RoundTowardsZero(SInt(R[n]) / SInt(R[m]))
```

**Edge case:** `SDIV(INT32_MIN, -1)` — the mathematical result is `+2³¹`, which doesn't fit. Cortex-M33 returns `0x80000000` (i.e. `INT32_MIN`) and **does not** raise a fault. Be aware if you mirror C's behaviour (which is undefined here).

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SDIV Rd, Rn, Rm` (32-bit only) |

Hardware-implemented; 2–11 cycles.

## Exceptions / faults

- **Divide-by-zero**: identical to UDIV. With `SCB->CCR.DIV_0_TRP = 1`, raises a UsageFault (`CFSR.UFSR.DIVBYZERO`). With the reset default of 0, silently returns `Rd = 0`.
- (no other faults).

## Example

### Example 1 — signed divmod and the INT_MIN/−1 corner

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SDIV demo: signed divmod (note rounding toward zero, not floor)
    ldr     r0, =-7
    movs    r1, #2
    sdiv    r2, r0, r1          @ r2 = -3   (C semantics; floor would be -4)
    mls     r3, r2, r1, r0      @ r3 = r0 - r2*r1 = -7 - (-6) = -1   (remainder)

    @ pathological case: INT32_MIN / -1
    ldr     r4, =0x80000000
    ldr     r5, =-1
    sdiv    r6, r4, r5          @ r6 = 0x80000000  (no fault, no overflow flag)
loop:
    b       loop
```

**Walkthrough:**

1. `sdiv r2, r0, r1` — `−7 / 2 = −3` because rounding is toward zero.
2. `mls r3, r2, r1, r0` — same trick as UDIV; gives `−1`, which has the **same sign as the dividend** under C semantics.
3. `sdiv r6, r4, r5` — the one case where signed divide can mathematically overflow. Hardware silently wraps, so an explicit pre-check (`if (a == INT32_MIN && b == -1)`) is on you if it matters.

### Example 2 — SDIV with an explicit divide-by-zero guard

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global reset_handler
    .thumb_func
reset_handler:
    ldr     r0, =-2400          @ dividend
    movs    r1, #5              @ divisor (could be zero at runtime)
    cmp     r1, #0
    beq     div_zero
    sdiv    r2, r0, r1          @ r2 = -480
    b       loop
div_zero:
    movs    r2, #0              @ sentinel: "no result"
loop:
    b       loop
```

**Walkthrough:**

1. `cmp r1, #0` + `beq div_zero` is the explicit guard you write when `SCB.CCR.DIV_0_TRP` is left at its reset default of 0 — otherwise SDIV silently returns 0 and downstream code can't tell "divided cleanly to 0" from "the divisor was zero".
2. `sdiv r2, r0, r1` — straight signed divide, rounds toward zero per C semantics.
3. For loud failure instead of a guard, set `SCB->CCR.DIV_0_TRP = 1` once at startup and let the UsageFault handler catch it — usually preferable in production firmware.

## See also

- [UDIV](UDIV.md) — unsigned divide
- [MLS](MLS.md) — partner instruction for remainders
- [SMULL](SMULL.md) — signed multiply that pairs nicely for fixed-point

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.155 — *SDIV*. Divide-by-zero trap: §B3.4 (CCR) / §B3.6 (UsageFault).
