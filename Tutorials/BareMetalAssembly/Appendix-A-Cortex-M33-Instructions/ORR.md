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

**When you'd actually use this** is the **set-bits half** of read-modify-write on peripheral registers — to enable a clock, raise a GPIO output, or unmask an interrupt: `ldr r1, [r0]; orr r1, r1, #ENABLE; str r1, [r0]`. It's also how you reassemble a config word from individually-prepared sub-fields (each shifted into place with `LSL`) into one final register write. Pair it with `BIC` for the canonical "clear the old bits, then OR in the new ones" idiom on multi-bit fields.

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

### Example 1 — build a 32-bit constant and set a flag

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

### Example 2 — enable two clock-gate bits at once

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Enable two clock gates (USART0 = bit 3, TIMER1 = bit 7) in one RMW.
    ldr     r1, =0x40000020        @ pretend CMU_CLOCK_ENABLE register
    ldr     r0, [r1]
    orr     r0, r0, #((1 << 3) | (1 << 7))   @ set both bits at once
    str     r0, [r1]
loop:
    b   loop
```

**Walkthrough:** A single `ORR` with a composite mask is cheaper than two separate `ORR`s and avoids a second store back to the peripheral. `0x88` fits trivially as a Thumb-2 modified immediate, so the whole sequence is just three instructions plus the address load.

## See also

- [AND](AND.md) — bitwise AND (clear via mask).
- [BIC](BIC.md) — bitwise AND-NOT (the way you clear bits).
- [ORN](ORN.md) — bitwise OR with the bitwise-NOT of operand2.
- [EOR](EOR.md) — bitwise XOR.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.117 — *ORR (immediate)* and §C2.4.118 — *ORR (register)*.
