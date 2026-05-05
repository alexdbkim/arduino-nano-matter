# SMLAL — signed multiply and accumulate into a 64-bit pair

## Class & availability

- **Class:** Multiply (arithmetic)
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLAL{<cond>} <RdLo>, <RdHi>, <Rn>, <Rm>
```

`RdHi:RdLo = (RdHi:RdLo) + SignExtend(Rn) × SignExtend(Rm)`. Treats both factors as signed and sign-extends the partial product before adding to the 64-bit accumulator.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<RdLo>` | low 32 bits of accumulator — read AND written | `R0`–`R12` |
| `<RdHi>` | high 32 bits of accumulator — read AND written | `R0`–`R12`, must differ from `<RdLo>` |
| `<Rn>` | first factor (signed) | `R0`–`R12` |
| `<Rm>` | second factor (signed) | `R0`–`R12` |

**Operand order:** low first, then high. Initialise the pair before the first SMLAL (usually with `movs RdLo, #0; movs RdHi, #0` if you want a zero start, or load a 64-bit bias).

## Operation (pseudocode)

```text
if ConditionPassed() then
    acc    = (SInt(R[dHi]) << 32) | UInt(R[dLo])      // signed 64-bit
    result = acc + SInt(R[n]) * SInt(R[m])
    R[dHi] = result<63:32>
    R[dLo] = result<31:0>
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never on Armv8-M.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMLAL RdLo, RdHi, Rn, Rm` (32-bit only) |

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
    @ SMLAL demo: signed dot product into a 64-bit accumulator
    @ acc = a0*b0 + a1*b1 (signed, no overflow even with worst-case 32-bit inputs)
    movs    r4, #0              @ acc.lo
    movs    r5, #0              @ acc.hi

    ldr     r0, =-1000          @ a0
    ldr     r1, = 2000          @ b0
    smlal   r4, r5, r0, r1      @ acc += -2_000_000

    ldr     r0, = 3000          @ a1
    ldr     r1, =-4000          @ b1
    smlal   r4, r5, r0, r1      @ acc += -12_000_000  -> acc = -14_000_000
loop:
    b       loop
```

**Walkthrough:**

1. The accumulator is initialised to 0 across both registers. SMLAL needs the pair to already hold a sane signed value; you can also seed it with a non-zero bias (split into lo/hi) before the loop.
2. Each `smlal` adds a signed product to the 64-bit accumulator in one cycle. Even with two `INT32_MIN × INT32_MAX` products you cannot overflow 64 bits — that's the whole point of accumulating wide.

## See also

- [SMULL](SMULL.md) — non-accumulating signed multiply
- [UMLAL](UMLAL.md) — unsigned accumulating multiply
- [MLA](MLA.md) — 32-bit accumulating multiply

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.171 — *SMLAL*.
