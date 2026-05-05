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

## See also

- [AND](AND.md) — `BIC Rn, Rm` ≡ `AND Rn, ~Rm`.
- [ORR](ORR.md) — to *set* bits.
- [ORN](ORN.md) — `Rn OR (NOT Rm)`, the OR-side cousin.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.15 — *BIC (immediate)* and §C2.4.16 — *BIC (register)*.
