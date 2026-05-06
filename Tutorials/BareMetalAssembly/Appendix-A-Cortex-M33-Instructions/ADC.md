# ADC — add with carry 
The building block of multi-word addition

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

**When you'd actually use this**: ADC is purely the second-half partner of an `ADDS` — you reach for it any time a value doesn't fit in 32 bits. The textbook case is a 64-bit add (`ADDS` low, `ADC` high), but the same pattern extends to 96-bit, 128-bit, and arbitrary big-int math used by RSA, ECC, and `__int128` emulation in libgcc. Without ADC you'd have to re-derive the carry with a compare-and-add, costing an extra instruction per limb. Watch out: ADC always *reads* the C flag, so any flag-touching instruction sneaking between the `ADDS` and the `ADC` silently breaks the wide arithmetic.

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

### Example 1 — 64-bit add of two 64-bit operands

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

### Example 2 — incrementing a 64-bit counter by 1

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global reset_handler
    .thumb_func
reset_handler:
    ldr     r0, =0xFFFFFFFF     @ counter.lo (one tick from rollover)
    ldr     r1, =0x00000007     @ counter.hi
    adds    r0, r0, #1          @ low++ wraps to 0; C=1 signals carry-out
    adc     r1, r1, #0          @ propagate the carry into the high half
loop:
    b       loop
```

**Walkthrough:**

1. `adds r0, r0, #1` — incrementing `0xFFFFFFFF` wraps to `0x00000000` and sets C=1.
2. `adc r1, r1, #0` — adds 0 + carry to the high word, bumping it from 7 to 8. Without the ADC step the 64-bit counter would silently lose the rollover and stay at `0x00000007_00000000`.
3. The `adc Rh, Rh, #0` pattern is the canonical way to extend any 32-bit increment to 64-bit: `adds` for the low word, then a single `adc` with an immediate zero.

## See also

- [ADD](ADD.md) — same operation without the carry input
- [SBC](SBC.md) — the subtract-with-borrow counterpart for multi-word subtract
- [UMLAL](UMLAL.md) / [SMLAL](SMLAL.md) — accumulating into a 64-bit pair in one instruction

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.1 — *ADC (immediate)*, §C2.4.2 — *ADC (register)*.
