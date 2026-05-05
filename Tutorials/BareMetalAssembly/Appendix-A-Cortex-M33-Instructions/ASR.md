# ASR — arithmetic shift right (signed divide by powers of two)

## Class & availability

- **Class:** Shift/Rotate
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
ASR{S}{<cond>} {<Rd>,} <Rm>, #<imm>           @ immediate form, imm = 1..32
ASR{S}{<cond>} {<Rd>,} <Rn>, <Rs>             @ register form
```

Right-shift `Rm`/`Rn` by N bits, **replicating bit 31** (the sign bit) into the vacated high bits. The last bit shifted out lands in C with `S`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR; R0–R7 (T1) |
| `<Rm>` / `<Rn>` | source register | R0–R12, LR; R0–R7 (T1) |
| `<Rs>` | shift-amount register | only low 8 bits used |
| `#<imm>` | shift amount | 1..32 (`ASR #32` makes every bit equal to old bit 31; result is 0 or −1) |

## Operation (pseudocode)

```text
if ConditionPassed() then
    n = (immediate form) ? imm : UInt(R[s]<7:0>)
    (result, carry) = ASR_C(R[m], n)        @ shift right, sign-extend
    R[d] = result
    if S == '1' then
        APSR.N = result<31>                 @ same as old bit 31
        APSR.Z = IsZeroBit(result)
        APSR.C = carry
        @ APSR.V unchanged
```

Register form: `Rs<7:0> == 0` ⇒ C unchanged. `Rs >= 32` ⇒ result is `0` if old bit 31 = 0 else `0xFFFFFFFF`; C = old bit 31.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | – | – |

`ASRS` only. N keeps the sign of the input, since bit 31 is preserved.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `ASRS <Rd>, <Rm>, #<imm5>` — immediate, low registers |
| T2 | 16-bit | `ASRS <Rdn>, <Rm>` — register, low registers |
| T2 | 32-bit | `ASR{S}.W <Rd>, <Rm>, #<imm>` — immediate |
| T2 | 32-bit | `ASR{S}.W <Rd>, <Rn>, <Rs>` — register |

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
    @ ASR demo: signed divide-by-2 and signed field extract.
    ldr     r0, =0xFFFFFFF0        @ -16 in two's complement
    asr     r1, r0, #1             @ r1 = 0xFFFFFFF8 = -8 (signed /2)
    asr     r2, r0, #4             @ r2 = 0xFFFFFFFF = -1
    mov     r3, #2
    asrs    r4, r0, r3             @ register form: r4 = -4, N=1, Z=0, C=0
loop:
    b   loop
```

**Walkthrough:**

1. `asr r1, r0, #1` — signed `/2`. Compare with `lsr r1, r0, #1` which would have produced `0x7FFFFFF8` — totally wrong for a negative value.
2. `asr r2, r0, #4` — `-16 >> 4 = -1`. Sign extension fills the top.
3. `asrs r4, r0, r3` — register-form variant. `S` is on, so N reflects the (preserved) sign and you can branch on it.

This is the part that bites people: ARM's `ASR` rounds **toward minus infinity** for negative inputs, not toward zero. `(-1) ASR 1 = -1`, not `0`. C compilers know this and emit corrections when language semantics demand truncation.

## See also

- [LSR](LSR.md) — unsigned right shift (zero fill). Pick `LSR` for `unsigned`, `ASR` for `int`.
- [LSL](LSL.md), [ROR](ROR.md), [RRX](RRX.md) — the rest of the shifter family.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.13 — *ASR (immediate)* and §C2.4.14 — *ASR (register)*.
