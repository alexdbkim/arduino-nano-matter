# LSR — logical shift right (unsigned divide by powers of two)

## Class & availability

- **Class:** Shift/Rotate
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
LSR{S}{<cond>} {<Rd>,} <Rm>, #<imm>           @ immediate form, imm = 1..32
LSR{S}{<cond>} {<Rd>,} <Rn>, <Rs>             @ register form
```

Shift right, **zero-fill** on the left. The last bit shifted out (bit 0 → C-out) goes into C with `S`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR; R0–R7 (T1) |
| `<Rm>` / `<Rn>` | source register | R0–R12, LR; R0–R7 (T1) |
| `<Rs>` | shift-amount register | only the low 8 bits used |
| `#<imm>` | shift amount | 1..32 (an `LSR #32` is encoded with the imm5 field = 0) |

## Operation (pseudocode)

```text
if ConditionPassed() then
    n = (immediate form) ? imm : UInt(R[s]<7:0>)
    (result, carry) = LSR_C(R[m], n)
    R[d] = result
    if S == '1' then
        APSR.N = result<31>                  @ always 0 for n>=1, 32-bit zero-fill
        APSR.Z = IsZeroBit(result)
        APSR.C = carry
        @ APSR.V unchanged
```

For the register form, `Rs<7:0> == 0` leaves C unchanged. `Rs >= 32` zeroes the result; for exactly 32, C = bit 31 of `Rn`; for `>32`, C = 0.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | – | – |

`LSRS` only. With any `n>=1`, N is always 0 (top bit becomes 0).

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `LSRS <Rd>, <Rm>, #<imm5>` — immediate, low registers |
| T2 | 16-bit | `LSRS <Rdn>, <Rm>` — register, low registers |
| T2 | 32-bit | `LSR{S}.W <Rd>, <Rm>, #<imm>` — immediate |
| T2 | 32-bit | `LSR{S}.W <Rd>, <Rn>, <Rs>` — register |

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
    @ LSR demo: extract the high byte of a 32-bit value, both forms.
    ldr     r0, =0xDEADBEEF
    lsr     r1, r0, #24            @ r1 = 0x000000DE (immediate form)
    mov     r2, #24
    lsr     r3, r0, r2             @ r3 = 0x000000DE (register form)
    lsrs    r4, r0, #1             @ r4 = 0x6F56DF77, C = bit 0 of r0 = 1
loop:
    b   loop
```

**Walkthrough:**

1. `lsr r1, r0, #24` — pull the top byte down to the bottom. Use this for `(uint32_t)x >> 24`-style field extracts.
2. `lsr r3, r0, r2` — register form, useful when the shift count is computed at runtime (e.g. variable-width bitfield decoding).
3. `lsrs r4, r0, #1` — sets C to the bit that fell off the right end. Pair with `ADC`/`ADCS` for unsigned multi-precision divides by two.

This is the part that bites people: `LSR` is the **unsigned** divide; if you shift a negative number with `LSR` you get a huge positive number. Use [`ASR`](ASR.md) for signed divide-by-two.

## See also

- [LSL](LSL.md) — shift left.
- [ASR](ASR.md) — arithmetic (sign-preserving) right shift.
- [ROR](ROR.md), [RRX](RRX.md) — rotates.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.67 — *LSR (immediate)* and §C2.4.68 — *LSR (register)*.
