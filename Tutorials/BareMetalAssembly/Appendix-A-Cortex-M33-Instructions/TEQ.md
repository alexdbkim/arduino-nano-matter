# TEQ — test equivalence: EOR that updates flags only

## Class & availability

- **Class:** Compare (logical test)
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
TEQ{<cond>} <Rn>, <Rm>{, <shift>}
TEQ{<cond>} <Rn>, #<const>
```

`TEQ` is `EORS` with the result discarded. `Rn == operand2` ⇔ result is zero ⇔ `Z=1`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rn>` | source register | R0–R12, LR |
| `<Rm>` | second source register | R0–R12, LR |
| `#<const>` | modified immediate | Thumb-2 modified immediate |
| `<shift>` | optional shift on `<Rm>` | `LSL`/`LSR`/`ASR`/`ROR` #1..31, or `RRX` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    (shifted, carry) = Shift_C(R[m], shift_t, shift_n, APSR.C)
    result = R[n] EOR shifted
    APSR.N = result<31>
    APSR.Z = IsZeroBit(result)
    APSR.C = carry
    @ APSR.V unchanged
    @ result itself is discarded
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | – | – |

Always updates N, Z, C.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `TEQ <Rn>, #<const>` — immediate. **No 16-bit form.** |
| T1 | 32-bit | `TEQ <Rn>, <Rm>{, <shift>}` — register. **No 16-bit form.** |

`TEQ` is Thumb-2 (32-bit) only.

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
    @ TEQ demo: equality test that does not affect V (unlike CMP).
    ldr     r0, =0xDEADBEEF
    ldr     r1, =0xDEADBEEF
    teq     r0, r1                 @ result = 0 -> Z = 1
    beq     match
    @ ... not equal
match:
    teq     r0, #0                 @ N reflects sign bit of r0 (=1)
loop:
    b   loop
```

**Walkthrough:**

1. `teq r0, r1` — same outcome as `cmp r0, r1` for the equality question, but **does not touch V**. Useful when you want to test equality inside arithmetic that already cares about V.
2. `teq r0, #0` — equivalent to "test if `r0` is zero, also setting N to its sign bit". A close cousin of `CMP r0, #0` and `MOVS r0, r0`.

This is the part that bites people: people reach for `CMP` for equality and that's fine, but `TEQ`'s extra trick is that **N gets the sign of `Rn ^ operand2`** — handy for "do these two values have the same sign?" when `operand2` is `Rm`: `TEQ Rn, Rm` then `BMI different_signs`.

## See also

- [EOR](EOR.md) — same operation, keeps the result.
- [TST](TST.md) — AND-based bit test.
- [CMP](CMP.md) — subtraction-based compare (also affects V).

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.193 — *TEQ (immediate)* and §C2.4.194 — *TEQ (register)*.
