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

**When you'd actually use this**: The textbook use is computing a remainder: `rem = a − (a/b)*b`, paired with `UDIV` or `SDIV` (Cortex-M has no modulo instruction). Beyond modulo, MLS appears in any "subtract a scaled term from a running value" pattern — error correction in Bresenham line drawing, residual computation in least-squares fits, or `target − k*sample` in proportional control. Like MLA there is no flag-setting form. Prefer it over separate `MUL` + `SUB` to save a cycle and a scratch register.

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

### Example 1 — remainder via UDIV + MLS

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

### Example 2 — residual term `target − gain × measured`

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global reset_handler
    .thumb_func
reset_handler:
    movs    r0, #1000           @ target value
    movs    r1, #50             @ measured sample
    movs    r2, #15             @ gain
    mls     r3, r1, r2, r0      @ r3 = 1000 - 50*15 = 250
loop:
    b       loop
```

**Walkthrough:**

1. `MLS` computes `Ra − Rn*Rm` in one cycle — exactly the shape of "how far off is the prediction?" in proportional control or linear regression.
2. The same instruction is the canonical "compute remainder from quotient" partner for `UDIV`/`SDIV`: replace `target` with the dividend and `gain*measured` with `quotient*divisor` and you have `a % b`.
3. Like `MLA`, there is no flag-setting form. Follow with `cmp r3, #0` if you need to branch on the sign of the residual.

## See also

- [MLA](MLA.md) — the additive counterpart
- [MUL](MUL.md) — the bare multiply
- [UDIV](UDIV.md) / [SDIV](SDIV.md) — pair with `MLS` to compute remainders

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.100 — *MLS*.
