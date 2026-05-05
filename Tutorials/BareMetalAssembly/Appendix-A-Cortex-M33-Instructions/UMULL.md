# UMULL — unsigned 32×32 → 64-bit multiply

## Class & availability

- **Class:** Multiply (arithmetic)
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UMULL{<cond>} <RdLo>, <RdHi>, <Rn>, <Rm>
```

`RdHi:RdLo = ZeroExtend(Rn) × ZeroExtend(Rm)` — full 64-bit unsigned product split across two registers.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<RdLo>` | destination, low 32 bits of product | `R0`–`R12` |
| `<RdHi>` | destination, high 32 bits of product | `R0`–`R12`, must differ from `<RdLo>` |
| `<Rn>` | first factor (treated as unsigned) | `R0`–`R12` |
| `<Rm>` | second factor (treated as unsigned) | `R0`–`R12` |

**Order matters and is easy to get wrong:** `UMULL RdLo, RdHi, Rn, Rm` — *low first, then high*. `RdLo == RdHi` is UNPREDICTABLE (the assembler will reject it).

## Operation (pseudocode)

```text
if ConditionPassed() then
    result = UInt(R[n]) * UInt(R[m])    // 64-bit unsigned product
    R[dHi] = result<63:32>
    R[dLo] = result<31:0>
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never on Armv8-M (the architecturally-deprecated `UMULLS` form is not encodable).

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `UMULL RdLo, RdHi, Rn, Rm` (32-bit only) |

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
    @ UMULL demo: full 64-bit product of two 32-bit unsigned values
    ldr     r0, =0xFFFFFFFF     @ 2^32 - 1
    ldr     r1, =0x00000002     @ 2
    umull   r2, r3, r0, r1      @ r3:r2 = 0x1FFFFFFFE
    @ low word in r2 = 0xFFFFFFFE, high word in r3 = 0x00000001
    @ scale a 32-bit count by a Q16.16 fixed-point factor:
    ldr     r4, =1000
    ldr     r5, =0x00018000     @ 1.5 in Q16.16
    umull   r6, r7, r4, r5      @ r7:r6 = product, then shift right 16
    lsrs    r6, r6, #16
    orr     r6, r6, r7, lsl #16 @ r6 = (r4 * r5) >> 16 = 1500
loop:
    b       loop
```

**Walkthrough:**

1. `umull r2, r3, r0, r1` — produces a true 64-bit product. Compare with [MUL](MUL.md), which would have given just `0xFFFFFFFE` and silently dropped the high bit.
2. The Q16.16 sequence shows the canonical "fixed-point multiply": multiply 32×32 → 64, then shift right by the fractional bit count. Without UMULL you'd lose precision.

## See also

- [SMULL](SMULL.md) — signed counterpart
- [UMLAL](UMLAL.md) — unsigned multiply-accumulate into a 64-bit pair
- [MUL](MUL.md) — only the low 32 bits

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.230 — *UMULL*.
