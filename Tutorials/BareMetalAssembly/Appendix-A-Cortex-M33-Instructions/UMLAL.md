# UMLAL — unsigned multiply and accumulate into a 64-bit pair

## Class & availability

- **Class:** Multiply (arithmetic)
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UMLAL{<cond>} <RdLo>, <RdHi>, <Rn>, <Rm>
```

`RdHi:RdLo = (RdHi:RdLo) + ZeroExtend(Rn) × ZeroExtend(Rm)`. Reads *and* writes the 64-bit pair — it's a true accumulator.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<RdLo>` | low 32 bits — read AND written | `R0`–`R12` |
| `<RdHi>` | high 32 bits — read AND written | `R0`–`R12`, must differ from `<RdLo>` |
| `<Rn>` | first factor (unsigned) | `R0`–`R12` |
| `<Rm>` | second factor (unsigned) | `R0`–`R12` |

**Operand order:** low-first, then high. The pair must be initialised before the first `UMLAL` — usually with `movs RdLo, #0; movs RdHi, #0`.

## Operation (pseudocode)

```text
if ConditionPassed() then
    acc    = (UInt(R[dHi]) << 32) | UInt(R[dLo])
    result = acc + UInt(R[n]) * UInt(R[m])
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
| T1 | 32-bit | `UMLAL RdLo, RdHi, Rn, Rm` (32-bit only) |

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
    @ UMLAL demo: 64-bit running sum of unsigned 32-bit samples
    @ r4:r5 will hold the accumulator (lo:hi)
    movs    r4, #0              @ acc.lo = 0
    movs    r5, #0              @ acc.hi = 0
    movs    r6, #1              @ a "weight" (multiplier)

    ldr     r0, =0xFFFFFFFF
    umlal   r4, r5, r0, r6      @ acc += 0xFFFFFFFF * 1
    ldr     r0, =0x00000002
    umlal   r4, r5, r0, r6      @ acc += 2  -> acc = 0x100000001
    @ now r5 = 1, r4 = 1
loop:
    b       loop
```

**Walkthrough:**

1. The accumulator is zeroed in two registers. With UMLAL there is no "first multiply, then accumulate" split — every iteration is one instruction.
2. After two `umlal`s, the running sum has exceeded 2³², so `r5` (the high half) is non-zero. Compare with using plain ADDs into a single register, which would silently lose that bit.

## See also

- [UMULL](UMULL.md) — the non-accumulating form
- [SMLAL](SMLAL.md) — the signed counterpart
- [MLA](MLA.md) — 32-bit accumulating multiply

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.228 — *UMLAL*.
