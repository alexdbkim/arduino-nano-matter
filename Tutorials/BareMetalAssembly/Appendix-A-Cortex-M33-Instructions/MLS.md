# MLS — multiply-subtract: `Rd = Ra − (Rn × Rm)`

## Class & availability

- **Class:** Multiply (arithmetic)
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
MLS{<cond>} <Rd>, <Rn>, <Rm>, <Ra>
```

Low 32 bits of `Ra − Rn*Rm`. Like `MLA` but subtractive.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | `R0`–`R12` |
| `<Rn>` | first factor | `R0`–`R12` |
| `<Rm>` | second factor | `R0`–`R12` |
| `<Ra>` | minuend (product is subtracted from this) | `R0`–`R12` |

`PC`, `SP`, `LR` are forbidden as any operand. No flag-setting form.

## Operation (pseudocode)

```text
if ConditionPassed() then
    operand1 = SInt(R[n])
    operand2 = SInt(R[m])
    addend   = SInt(R[a])
    result   = addend - operand1 * operand2
    R[d] = result<31:0>
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never. There is no `MLSS`.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `MLS Rd, Rn, Rm, Ra` (32-bit only) |

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
    @ MLS demo: compute remainder of unsigned division using UDIV + MLS
    @ r0 % r1  ==  r0 - (r0 / r1) * r1
    movs    r0, #100
    movs    r1, #7
    udiv    r2, r0, r1          @ r2 = quotient = 14
    mls     r3, r2, r1, r0      @ r3 = r0 - r2*r1 = 100 - 98 = 2
loop:
    b       loop
```

**Walkthrough:**

1. `udiv r2, r0, r1` — Cortex-M33 has hardware divide but **no** modulo instruction. So you compute the quotient yourself.
2. `mls r3, r2, r1, r0` — fuses "multiply quotient by divisor, subtract from dividend" into one instruction. This is the canonical idiom for `%` on Cortex-M.

## See also

- [MLA](MLA.md) — the additive counterpart
- [MUL](MUL.md) — the bare multiply
- [UDIV](UDIV.md) / [SDIV](SDIV.md) — pair with `MLS` to compute remainders

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.100 — *MLS*.
