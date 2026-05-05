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

## See also

- [UDIV](UDIV.md) — unsigned divide
- [MLS](MLS.md) — partner instruction for remainders
- [SMULL](SMULL.md) — signed multiply that pairs nicely for fixed-point

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.155 — *SDIV*. Divide-by-zero trap: §B3.4 (CCR) / §B3.6 (UsageFault).
