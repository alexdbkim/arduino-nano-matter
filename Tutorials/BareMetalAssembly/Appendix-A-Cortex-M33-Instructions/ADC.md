# ADC — add with carry; the building block of multi-word addition

## Class & availability

- **Class:** Arithmetic
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
ADC{S}{<cond>} {<Rd>,} <Rn>, #<imm>
ADC{S}{<cond>} {<Rd>,} <Rn>, <Rm>{, <shift>}
```

`Rd = Rn + operand2 + APSR.C`. The `S` suffix updates flags from the result.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | T1: `R0`–`R7`. T2: `R0`–`R12` (PC/SP not allowed). |
| `<Rn>` | first source register | same set as `<Rd>` |
| `<Rm>` | second source register | any low/high register in 32-bit form |
| `#<imm>` | immediate | T2: 12-bit modified immediate (32-bit form only) |
| `<shift>` | optional shift on `<Rm>` | `LSL`/`LSR`/`ASR`/`ROR` #0–31, or `RRX` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    (result, carry, overflow) = AddWithCarry(R[n], operand2, APSR.C)
    R[d] = result
    if S == '1' then
        APSR.N = result<31>
        APSR.Z = IsZeroBit(result)
        APSR.C = carry
        APSR.V = overflow
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | ✓ | – |

Only with the `S` suffix. Note `ADC` *reads* C either way — it always uses the current carry as input.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `ADCS Rdn, Rm` (low regs, sets flags outside IT) |
| T2 | 32-bit | `ADC{S}.W Rd, Rn, Rm{, shift}` |
| T2 | 32-bit | `ADC{S}.W Rd, Rn, #<modified imm>` |

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
    @ ADC demo: 64-bit add of (r1:r0) + (r3:r2) -> (r5:r4)
    ldr     r0, =0xFFFFFFF0     @ low word of A
    ldr     r1, =0x00000001     @ high word of A
    ldr     r2, =0x00000020     @ low word of B
    ldr     r3, =0x00000002     @ high word of B
    adds    r4, r0, r2          @ low add, sets carry
    adc     r5, r1, r3          @ high add picks up carry
loop:
    b       loop
```

**Walkthrough:**

1. `adds r4, r0, r2` — adds the low halves; the unsigned sum overflows 32 bits, so APSR.C is set to 1.
2. `adc r5, r1, r3` — adds the high halves *plus the carry from the low add*. Result in `r5:r4` is the full 64-bit sum. We didn't write `adcs` because the example doesn't need flags after the high add — but if you were chaining to a 96-bit add you would.

## See also

- [ADD](ADD.md) — same operation without the carry input
- [SBC](SBC.md) — the subtract-with-borrow counterpart for multi-word subtract
- [UMLAL](UMLAL.md) / [SMLAL](SMLAL.md) — accumulating into a 64-bit pair in one instruction

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.1 — *ADC (immediate)*, §C2.4.2 — *ADC (register)*.
