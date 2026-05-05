# ADD — add two values, optionally updating the flags

## Class & availability

- **Class:** Arithmetic
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
ADD{S}{<cond>} {<Rd>,} <Rn>, #<imm>
ADD{S}{<cond>} {<Rd>,} <Rn>, <Rm>{, <shift>}
ADD{<cond>}    <Rd>,  SP,  #<imm>          @ stack-pointer form
ADD{<cond>}    <Rd>,  PC,  #<imm>          @ assembles to ADR
```

The `S` suffix means "set the flags from the result". Without it, flags are untouched.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | T1 form: `R0`–`R7`. T2/T3: `R0`–`R12`, `LR`, `SP`. `PC` allowed only in the wide register form (and writing PC = branch). |
| `<Rn>` | first source register | same set as `<Rd>` for the variant |
| `<Rm>` | second source register | any low/high register in 32-bit form |
| `#<imm>` | immediate | T1: 0–7 or 0–255. T3: 12-bit "modified immediate" (rotated/expanded). T4: any 0–4095 (no flags). |
| `<shift>` | optional shift on `<Rm>` | `LSL`/`LSR`/`ASR`/`ROR` #0–31, or `RRX` |

If `<Rd>` is omitted the assembler uses `<Rn>` (so `add r0, r1` means `add r0, r0, r1`).

## Operation (pseudocode)

```text
if ConditionPassed() then
    (result, carry, overflow) = AddWithCarry(R[n], operand2, '0')
    if d == 15 then           // writing PC = branch
        ALUWritePC(result)
    else
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

Flags update **only** with the `S` suffix. Plain `ADD` leaves APSR alone — this is the part that bites people writing conditional code.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `ADDS Rd, Rn, Rm` (low regs, S implicit outside IT block) |
| T2 | 16-bit | `ADD Rdn, Rm` (any registers, no flags) |
| T3 | 32-bit | `ADD{S}.W Rd, Rn, Rm{, shift}` |
| T4 | 32-bit | `ADD{S}.W Rd, Rn, #<modified imm>` |
| T4 (imm12) | 32-bit | `ADDW Rd, Rn, #0..4095` (never sets flags) |
| SP form  | 16/32-bit | `ADD Rd, SP, #imm` |

Outside an IT block, the 16-bit T1 encoding **always** sets flags — `add r0, r1, r2` on three low registers will be assembled as `adds`. Use `.w` to force the 32-bit form if you need flags-untouched semantics on low registers.

## Exceptions / faults

- (none) for the arithmetic itself. Writing to PC performs an interworking branch; if the result has bit 0 clear a UsageFault (INVSTATE) is raised on the next fetch.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ ADD demo: sum two numbers, then sum-with-flags to test for overflow
    movs    r0, #200
    movs    r1, #100
    add     r2, r0, r1          @ r2 = 300, flags untouched
    ldr     r3, =0x7FFFFFFF     @ INT32_MAX
    adds    r4, r3, #1          @ r4 = 0x80000000, V=1 (signed overflow)
    bvs     overflow
    nop
overflow:
loop:
    b       loop
```

**Walkthrough:**

1. `add r2, r0, r1` — plain add, no `S`, so APSR is untouched even though the result is non-zero.
2. `adds r4, r3, #1` — `S` form, the sum wraps from `+INT_MAX` to `INT_MIN`, setting **V=1** and **N=1**.
3. `bvs overflow` — branches because V is set, demonstrating that only the `S` form is useful for follow-up conditional code.

## See also

- [ADC](ADC.md) — add with carry; chains 32-bit adds into a 64-bit add
- [SUB](SUB.md) — the inverse operation
- [ADR](ADR.md) — `ADD Rd, PC, #imm` written as a synthetic op
- [CMN](CMN.md) — `ADDS` that discards the result, for comparisons

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.4 — *ADD (immediate)*, §C2.4.5 — *ADD (register)*, §C2.4.6 — *ADD (SP plus immediate)*.
