# ORR — bitwise inclusive OR of two values

## Class & availability

- **Class:** Logical
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
ORR{S}{<cond>} {<Rd>,} <Rn>, <Rm>{, <shift>}
ORR{S}{<cond>} {<Rd>,} <Rn>, #<const>
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR, SP (32-bit forms); R0–R7 (T1) |
| `<Rn>` | first source register | same as `<Rd>` |
| `<Rm>` | second source register | R0–R12, LR |
| `#<const>` | modified immediate | Thumb-2 modified immediate |
| `<shift>` | optional shift on `<Rm>` | `LSL`/`LSR`/`ASR`/`ROR` #1..31, or `RRX` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    (shifted, carry) = Shift_C(R[m], shift_t, shift_n, APSR.C)
    result = R[n] OR shifted
    R[d] = result
    if S == '1' then
        APSR.N = result<31>
        APSR.Z = IsZeroBit(result)
        APSR.C = carry
        @ APSR.V unchanged
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | – | – |

Flags only update with `ORRS`. C is the shifter carry-out, not a real arithmetic carry.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `ORRS <Rdn>, <Rm>` — low registers, always sets flags |
| T2 | 32-bit | `ORR{S}.W <Rd>, <Rn>, #<const>` — immediate |
| T3 | 32-bit | `ORR{S}.W <Rd>, <Rn>, <Rm>{, <shift>}` — register with shift |

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
    @ ORR demo: build a 32-bit constant from two halves, then set a flag bit.
    movw    r0, #0xBEEF            @ r0 = 0x0000BEEF
    movt    r0, #0xDEAD            @ r0 = 0xDEADBEEF (movt+movw idiom)
    mov     r1, #0x01
    orr     r2, r0, r1, lsl #8     @ set bit 8: r2 = 0xDEADBFEF
    orrs    r3, r2, #0x80000000    @ set sign bit, flags now N=1
loop:
    b   loop
```

**Walkthrough:**

1. `movw`/`movt` build a full 32-bit constant — not strictly an `ORR`, but the idiomatic way to load it.
2. `orr r2, r0, r1, lsl #8` — shows the optional inline shift: OR in `r1 << 8`. This is the bread-and-butter pattern for "set bit N" in MMIO registers.
3. `orrs ... #0x80000000` — same operation but updates flags so you could branch on the result's sign.

## See also

- [AND](AND.md) — bitwise AND (clear via mask).
- [BIC](BIC.md) — bitwise AND-NOT (the way you clear bits).
- [ORN](ORN.md) — bitwise OR with the bitwise-NOT of operand2.
- [EOR](EOR.md) — bitwise XOR.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.117 — *ORR (immediate)* and §C2.4.118 — *ORR (register)*.
