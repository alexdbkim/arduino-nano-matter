# AND — bitwise AND of two values

## Class & availability

- **Class:** Logical
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
AND{S}{<cond>} {<Rd>,} <Rn>, <Rm>{, <shift>}
AND{S}{<cond>} {<Rd>,} <Rn>, #<const>
```

**When you'd actually use this** is the workhorse of **bit masking**. When you read a peripheral status register and only care about a couple of flag bits, you `AND` away the rest with a constant mask; the same trick keeps an index inside a power-of-two ring buffer (`and r0, r0, #(SIZE-1)` is one cycle, vs. dozens for a `UDIV`). The `ANDS` form lets you test-and-go in a single instruction — `ands r0, r0, #FLAG; bne handler` — saving the separate `TST` you'd otherwise need. For just isolating a single bit-field, `UBFX` may read cleaner, but plain `AND` with a mask works on every Thumb-2 core and is what compilers emit for `x & MASK`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR, SP (32-bit form); R0–R7 (T1) |
| `<Rn>` | first source register | same as `<Rd>`; if omitted, defaults to `<Rd>` |
| `<Rm>` | second source register | R0–R12, LR |
| `#<const>` | modified immediate | any value expressible as Thumb-2 modified immediate |
| `<shift>` | optional shift on `<Rm>` | `LSL`/`LSR`/`ASR`/`ROR` #1..31, or `RRX` |

The `S` suffix makes the instruction set N, Z and (when the operand2 carry-out is meaningful) C.

## Operation (pseudocode)

```text
if ConditionPassed() then
    (shifted, carry) = Shift_C(R[m], shift_t, shift_n, APSR.C)
    result = R[n] AND shifted          @ or AND with the immediate
    R[d] = result
    if S == '1' then
        APSR.N = result<31>
        APSR.Z = IsZeroBit(result)
        APSR.C = carry                  @ from the shifter / immediate carry
        @ APSR.V unchanged
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | – | – |

Flags update **only when the `S` suffix is present** (`ANDS`). C comes from the shifter carry-out, not from the AND itself; V is left alone.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `ANDS <Rdn>, <Rm>` — low registers only, always sets flags |
| T2 | 32-bit | `AND{S}.W <Rd>, <Rn>, #<const>` — immediate |
| T3 | 32-bit | `AND{S}.W <Rd>, <Rn>, <Rm>{, <shift>}` — register with optional shift |

## Exceptions / faults

- (none) — purely register-to-register / register-to-immediate.

## Example

### Example 1 — low-nibble masking

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ AND demo: keep only the low 4 bits of a value, then test it.
    ldr     r0, =0xDEADBEEF
    and     r1, r0, #0x0F          @ r1 = 0x0000000F
    ands    r2, r0, #0xF0000000    @ r2 = 0xD0000000, sets N=1, Z=0
    and     r3, r1, r2             @ r3 = 0, but no flags updated
    ands    r4, r3, r3             @ r4 = 0, sets Z=1
loop:
    b   loop
```

**Walkthrough:**

1. `and r1, r0, #0x0F` — masks off everything except bits [3:0]. No flag update.
2. `ands r2, r0, #0xF0000000` — same idea on the top nibble; the `S` makes N reflect bit 31 of the result.
3. `ands r4, r3, r3` — common idiom for "test if a register is zero" without clobbering it.

### Example 2 — branch on any peripheral flag

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Branch to handler if BUSY (bit 0) or ERROR (bit 4) is set in STATUS.
    ldr     r1, =0x40000000        @ pretend peripheral STATUS register
    ldr     r0, [r1]
    ands    r2, r0, #0x11          @ mask BUSY | ERROR; updates Z in one go
    bne     handler                @ Z=0 -> at least one flag was set
    b       done
handler:
done:
loop:
    b   loop
```

**Walkthrough:** `ANDS` does the masking and the flag update in a single instruction — no separate `TST` needed, and `r2` retains the masked bits in case you want to dispatch on which flag fired. Without `ANDS` you'd need `and r2, r0, #0x11; cmp r2, #0; bne handler` — three instructions for the same effect.

## See also

- [ORR](ORR.md) — bitwise OR (the other half of bit masking).
- [BIC](BIC.md) — `Rn AND NOT Rm`, useful for clearing bits.
- [TST](TST.md) — `AND` that *only* updates flags.
- [EOR](EOR.md) — bitwise XOR.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.9 — *AND (immediate)* and §C2.4.10 — *AND (register)*.
