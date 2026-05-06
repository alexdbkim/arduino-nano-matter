# BIC — bit clear: AND with the bitwise NOT of operand2

## Class & availability

- **Class:** Logical
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
BIC{S}{<cond>} {<Rd>,} <Rn>, <Rm>{, <shift>}
BIC{S}{<cond>} {<Rd>,} <Rn>, #<const>
```

`Rd = Rn AND (NOT operand2)`. Bits set in operand2 are **cleared** in `Rn`.

**When you'd actually use this** is the **clear-bits half** of read-modify-write on peripheral registers. To turn off a single feature bit without disturbing its siblings: `ldr r1, [r0]; bic r1, r1, #FEATURE; str r1, [r0]`. It pairs with `ORR` for the classic "clear the field, set the new value" idiom on multi-bit fields like clock dividers or pin modes. Doing the same with `AND #~MASK` works in theory but the inverted constant often doesn't fit as a Thumb-2 modified immediate, so `BIC #MASK` is both shorter and more readable.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR (32-bit forms); R0–R7 (T1) |
| `<Rn>` | first source register | same as `<Rd>` |
| `<Rm>` | second source register | R0–R12, LR |
| `#<const>` | modified immediate | Thumb-2 modified immediate |
| `<shift>` | optional shift on `<Rm>` | `LSL`/`LSR`/`ASR`/`ROR` #1..31, or `RRX` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    (shifted, carry) = Shift_C(R[m], shift_t, shift_n, APSR.C)
    result = R[n] AND NOT(shifted)
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

`BICS` only. C comes from the shifter, not from arithmetic.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `BICS <Rdn>, <Rm>` — low registers, always flags |
| T2 | 32-bit | `BIC{S}.W <Rd>, <Rn>, #<const>` — immediate |
| T3 | 32-bit | `BIC{S}.W <Rd>, <Rn>, <Rm>{, <shift>}` — register with shift |

## Exceptions / faults

- (none).

## Example

### Example 1 — clearing fields in a register

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ BIC demo: clear specific bits in a peripheral-style register value.
    ldr     r0, =0xDEADBEEF
    bic     r1, r0, #0xFF          @ clear low byte: r1 = 0xDEADBE00
    bic     r2, r1, #0x000F0000    @ clear nibble 4: r2 = 0xDEA0BE00
    mov     r3, #0x80000000
    bics    r4, r2, r3             @ also clears bit 31, sets flags
loop:
    b   loop
```

**Walkthrough:**

1. `bic r1, r0, #0xFF` — the typical "clear bits 7:0" pattern. Compare to `and r1, r0, #~0xFF` — same effect, but `BIC` reads more naturally and lets you state which bits you *want gone*.
2. `bic r2, r1, #0x000F0000` — chain another mask to scrub another field.
3. `bics ...` — clears bit 31 and updates flags, so a following `BPL`/`BMI` can branch on the new MSB.

### Example 2 — update a 2-bit MODE field

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ MODE field at bits [5:4] of a config register; change it to 0b10.
    ldr     r1, =0x40000004        @ pretend peripheral CONFIG register addr
    ldr     r0, [r1]
    bic     r0, r0, #(3 << 4)      @ clear bits [5:4]
    orr     r0, r0, #(2 << 4)      @ set bits [5:4] to 0b10
    str     r0, [r1]
loop:
    b   loop
```

**Walkthrough:** `BIC` clears the 2-bit field with the mask `0x30`; `ORR` drops the new value `0b10` into the same slot. The `AND`-equivalent would need the constant `0xFFFFFFCF`, which isn't a Thumb-2 modified immediate — so the assembler would emit a literal-pool load. `BIC #0x30` keeps it to one 32-bit instruction.

## See also

- [AND](AND.md) — `BIC Rn, Rm` ≡ `AND Rn, ~Rm`.
- [ORR](ORR.md) — to *set* bits.
- [ORN](ORN.md) — `Rn OR (NOT Rm)`, the OR-side cousin.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.15 — *BIC (immediate)* and §C2.4.16 — *BIC (register)*.
