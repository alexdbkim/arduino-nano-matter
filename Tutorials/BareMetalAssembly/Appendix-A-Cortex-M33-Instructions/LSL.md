# LSL — logical shift left (multiply by powers of two)

## Class & availability

- **Class:** Shift/Rotate
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
LSL{S}{<cond>} {<Rd>,} <Rm>, #<imm5>          @ immediate form
LSL{S}{<cond>} {<Rd>,} <Rn>, <Rs>             @ register form
```

Shift `Rm`/`Rn` left by N bit positions, zero-filling on the right. Bit 32 (the bit shifted out) lands in C when `S` is set.

**When you'd actually use this** is **multiplying by a power of two** and **packing fields into a register**. `lsl r0, r0, #2` is `r0 * 4` in one cycle — far cheaper than `MUL`. It's how you scale a word index into a byte offset before a load (`ldr r2, [r3, r1, lsl #2]` indexes a 32-bit array), and how you slot a 4-bit field into bits [11:8] before `ORR`-ing it into a config word. It's also half of the standard zero-extend trick: `lsl #8` then `lsr #8` clears the top byte cleanly.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR; R0–R7 (T1) |
| `<Rm>` / `<Rn>` | source register | R0–R12, LR; R0–R7 (T1) |
| `<Rs>` | shift-amount register | only the low 8 bits used; values >31 produce 0 (and C=0) |
| `#<imm5>` | shift amount | 1..31 (a shift of 0 is encoded as `MOV`) |

## Operation (pseudocode)

```text
if ConditionPassed() then
    n = (immediate form) ? imm5 : UInt(R[s]<7:0>)
    (result, carry) = LSL_C(R[m], n)        @ result = R[m] << n, carry = bit shifted out
    R[d] = result
    if S == '1' then
        APSR.N = result<31>
        APSR.Z = IsZeroBit(result)
        APSR.C = carry                       @ for n=0 (register form), C is unchanged
        @ APSR.V unchanged
```

For the register form, if `Rs<7:0> == 0`, C is unchanged and the value is simply copied. If `Rs<7:0> >= 32`, the result is 0 and (for `>32`) C is also 0; for exactly 32, C is bit 0 of `Rn`.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | – | – |

`LSLS` only.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `LSLS <Rd>, <Rm>, #<imm5>` — immediate, low registers, always sets flags |
| T2 | 16-bit | `LSLS <Rdn>, <Rm>` — register, low registers, always sets flags |
| T2 | 32-bit | `LSL{S}.W <Rd>, <Rm>, #<imm5>` — immediate |
| T2 | 32-bit | `LSL{S}.W <Rd>, <Rn>, <Rs>` — register |

## Exceptions / faults

- (none).

## Example

### Example 1 — immediate vs register shift

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ LSL demo: both immediate and register forms.
    mov     r0, #1
    lsl     r1, r0, #4             @ r1 = 16 (immediate form)
    mov     r2, #8
    lsl     r3, r0, r2             @ r3 = 256 (register form, shift count in r2)
    ldr     r4, =0x80000000
    lsls    r5, r4, #1             @ r5 = 0, C=1 (bit 31 fell out the top), Z=1
loop:
    b   loop
```

**Walkthrough:**

1. `lsl r1, r0, #4` — immediate form, multiply by 16. The compiler emits this for `x << 4`.
2. `lsl r3, r0, r2` — register form, shift count comes from `r2`. Use this for variable-amount shifts.
3. `lsls r5, r4, #1` — flag-setting variant. The MSB falls into C; perfect for software multi-precision shifts that chain `LSLS` then `ADC`/`ADCS`.

### Example 2 — pack a nibble into bits [11:8]

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Insert the 4-bit value 0xA into bits [11:8] of a config word.
    ldr     r0, =0x12340078        @ existing config (bits [11:8] already clear)
    mov     r1, #0xA
    orr     r0, r0, r1, lsl #8     @ r0 = 0x12340A78
loop:
    b   loop
```

**Walkthrough:** The shifted-register form lets `ORR` do the `LSL` for free — the CPU shifts `r1` by 8 inside the same instruction and ORs the result. If the destination field weren't already clear you'd `BIC` it first. Without the inline shift this would be two instructions: `lsl r1, r1, #8; orr r0, r0, r1`.

## See also

- [LSR](LSR.md) — logical shift right (zero fill).
- [ASR](ASR.md) — arithmetic shift right (sign fill).
- [ROR](ROR.md) — rotate right.
- [MOV](MOV.md) — `LSL #0` is just a `MOV`; the assembler may fold it.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.65 — *LSL (immediate)* and §C2.4.66 — *LSL (register)*.
