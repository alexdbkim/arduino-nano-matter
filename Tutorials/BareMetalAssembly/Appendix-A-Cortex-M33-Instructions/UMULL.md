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

**When you'd actually use this**: UMULL is for the *full* product when 32 bits aren't enough — Q-format fixed-point math (multiply a 32-bit count by a Q32 reciprocal then take just the high half to do a divide-by-constant), large unsigned hash mixing, and 64-bit nanosecond time arithmetic. The "multiply-then-take-high" idiom (only `RdHi` matters) is how compilers implement `x / const`: a 1-cycle MUL + UMULL + shift comfortably beats an 11-cycle UDIV. Substitute SMULL the moment one of the inputs can be negative; UMULL would zero-extend it and silently give the wrong high half.

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

### Example 1 — full 64-bit product and Q16.16 multiply

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

### Example 2 — divide-by-constant via multiply-by-reciprocal (take-high)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global reset_handler
    .thumb_func
reset_handler:
    ldr     r0, =1000000        @ x  (e.g. microseconds)
    ldr     r1, =0x10C6F7A1     @ Q32 magic ~ 2^32 / 1000
    umull   r2, r3, r0, r1      @ r3:r2 = x * magic
    @ r3 alone holds approximately x / 1000 = 1000
loop:
    b       loop
```

**Walkthrough:**

1. To divide by 1000 we multiply by the Q32 fixed-point reciprocal of 1000 and keep only the high half — `r3` gives the integer quotient directly.
2. `umull r2, r3, r0, r1` runs in a few cycles; the equivalent `udiv` would take up to 11. This is exactly the trick the compiler uses whenever it sees a divide by a compile-time constant.
3. The magic number must be chosen carefully so the high half is correct across the full input range — tools like libdivide compute these for you. Substitute `SMULL` if either operand can be negative.

## See also

- [SMULL](SMULL.md) — signed counterpart
- [UMLAL](UMLAL.md) — unsigned multiply-accumulate into a 64-bit pair
- [MUL](MUL.md) — only the low 32 bits

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.230 — *UMULL*.
