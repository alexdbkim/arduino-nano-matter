# SUB — subtract two values, optionally updating the flags

## Class & availability

- **Class:** Arithmetic
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SUB{S}{<cond>} {<Rd>,} <Rn>, #<imm>
SUB{S}{<cond>} {<Rd>,} <Rn>, <Rm>{, <shift>}
SUB{<cond>}    <Rd>,  SP,  #<imm>          @ stack-pointer form
```

`Rd = Rn − operand2`. The `S` suffix sets flags from the result.

**When you'd actually use this**: Decrementing a loop counter (the canonical `subs Rn, #1; bne loop` pattern), computing a buffer length as `end − begin`, pointer rewinds, and generating a small negative immediate. With the `S` suffix you immediately get the compare flags, so `BCC`/`BCS`/`BNE`/`BEQ` work without an explicit `CMP`. Just remember ARM's inverted borrow — `BCC` after `SUBS` means "branch if unsigned less-than" (because `C=0` is a borrow), opposite to x86 conventions. For wide subtraction, `SUBS` must be the *first* instruction of an `SBC` chain or the borrow won't propagate.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | T1: `R0`–`R7`. T3/T4: `R0`–`R12`, `LR`, `SP`. |
| `<Rn>` | minuend | same set as `<Rd>` for the variant |
| `<Rm>` | subtrahend (register) | any in 32-bit form |
| `#<imm>` | immediate subtrahend | T1: 0–7. T2: 0–255. T3: 12-bit modified imm. T4: any 0–4095 (`SUBW`, no flags). |
| `<shift>` | optional shift on `<Rm>` | `LSL`/`LSR`/`ASR`/`ROR` #0–31, or `RRX` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    (result, carry, overflow) = AddWithCarry(R[n], NOT(operand2), '1')
    R[d] = result
    if S == '1' then
        APSR.N = result<31>
        APSR.Z = IsZeroBit(result)
        APSR.C = carry          // C = NOT borrow
        APSR.V = overflow
```

Subtract is implemented as `Rn + ~op2 + 1`. That's why **C means "no borrow"** on ARM — opposite to x86.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | ✓ | – |

Only with the `S` suffix. `SUBW` (T4) **never** sets flags even though there's no `S` syntax to forbid.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `SUBS Rd, Rn, Rm` (low regs) |
| T2 | 16-bit | `SUBS Rd, Rn, #imm3` / `SUBS Rdn, #imm8` |
| T3 | 32-bit | `SUB{S}.W Rd, Rn, Rm{, shift}` |
| T3 | 32-bit | `SUB{S}.W Rd, Rn, #<modified imm>` |
| T4 | 32-bit | `SUBW Rd, Rn, #0..4095` (no flags) |
| SP form | 16/32-bit | `SUB SP, SP, #imm` and `SUB Rd, SP, #imm` |

## Exceptions / faults

- (none).

## Example

### Example 1 — countdown loop and unsigned compare via SUBS

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SUB demo: countdown loop using SUBS + BNE
    movs    r0, #5
count:
    subs    r0, r0, #1          @ r0--, sets Z when it reaches 0
    bne     count               @ keep going while non-zero
    @ unsigned compare: did r1 < r2?
    movs    r1, #3
    movs    r2, #7
    subs    r3, r1, r2          @ r3 = -4, C=0 (borrow occurred)
    bcc     was_less            @ branch if r1 < r2 (unsigned)
    nop
was_less:
loop:
    b       loop
```

**Walkthrough:**

1. `subs r0, r0, #1` — decrement and update Z. The classic loop pattern.
2. `bne count` — pure flag-driven branch; no compare instruction needed.
3. `subs r3, r1, r2` — produces a borrow because 3 < 7, so APSR.C clears (remember: C = !borrow).
4. `bcc was_less` — "branch if carry clear" is the canonical "branch if unsigned less than" after a `SUBS` or `CMP`.

### Example 2 — buffer-length difference and "is it empty?" branch

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global reset_handler
    .thumb_func
reset_handler:
    ldr     r0, =0x20000100     @ end pointer
    ldr     r1, =0x20000040     @ begin pointer
    subs    r2, r0, r1          @ r2 = 0xC0 = 192 bytes; flags reflect r2
    beq     empty               @ Z=1 means end == begin -> empty buffer
    lsr     r2, r2, #2          @ /4 -> 48 word elements
    b       loop
empty:
    movs    r2, #0
loop:
    b       loop
```

**Walkthrough:**

1. `subs r2, r0, r1` — the canonical `end − begin` to size up a buffer. The `S` suffix gives you the compare flags for free.
2. `beq empty` reuses those flags: Z=1 only when `r0 == r1`, i.e. the buffer is empty. No separate `CMP` needed.
3. `lsr r2, r2, #2` converts the byte difference to word count. Because the buffer is word-aligned this divide-by-4 is exact; for arbitrary element sizes you'd reach for `UDIV` instead.

## See also

- [ADD](ADD.md) — the inverse
- [SBC](SBC.md) — subtract with borrow, for multi-word subtraction
- [RSB](RSB.md) — reverse subtract (`Rd = op2 − Rn`)
- [CMP](CMP.md) — `SUBS` whose result is discarded, used for compares

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.196 — *SUB (immediate)*, §C2.4.197 — *SUB (register)*, §C2.4.198 — *SUB (SP minus immediate)*.
