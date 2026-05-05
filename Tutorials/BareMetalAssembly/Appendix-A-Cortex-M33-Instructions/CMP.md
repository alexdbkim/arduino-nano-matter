# CMP — compare: subtract and set flags, discard the result

## Class & availability

- **Class:** Compare
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
CMP{<cond>} <Rn>, <Rm>{, <shift>}
CMP{<cond>} <Rn>, #<const>
```

`CMP Rn, op2` is `SUBS` with the result thrown away. It sets N, Z, C, V exactly as `SUBS` would. Always sets flags — there is no `S` suffix because flag-setting *is* the instruction.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rn>` | left-hand value | R0–R12, LR; R0–R7 (T1); any (T2 high register form) |
| `<Rm>` | right-hand register | R0–R12, LR |
| `#<const>` | immediate | 0..255 (T1); Thumb-2 modified immediate (T2) |
| `<shift>` | optional shift on `<Rm>` | `LSL`/`LSR`/`ASR`/`ROR` #1..31, or `RRX` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    (result, carry, overflow) = AddWithCarry(R[n], NOT(operand2), '1')
    APSR.N = result<31>
    APSR.Z = IsZeroBit(result)
    APSR.C = carry        @ = NOT borrow: 1 if no borrow (Rn >= operand2 unsigned)
    APSR.V = overflow     @ signed overflow
```

This is the same machinery as `SUBS Rd, Rn, op2` — only the destination write is suppressed.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | ✓ | – |

Always.

## Condition codes after `CMP Rn, Rm`

| Branch | Taken when | Meaning |
|--------|------------|---------|
| `BEQ` | Z = 1 | `Rn == Rm` |
| `BNE` | Z = 0 | `Rn != Rm` |
| `BCS`/`BHS` | C = 1 | `Rn >= Rm` (unsigned) |
| `BCC`/`BLO` | C = 0 | `Rn < Rm` (unsigned) |
| `BMI` | N = 1 | result is negative |
| `BPL` | N = 0 | result is non-negative |
| `BGE` | N = V | `Rn >= Rm` (signed) |
| `BLT` | N != V | `Rn < Rm` (signed) |
| `BGT` | Z=0 && N=V | `Rn > Rm` (signed) |
| `BLE` | Z=1 \|\| N!=V | `Rn <= Rm` (signed) |

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `CMP <Rn>, #<imm8>` — Rn in R0–R7, imm 0..255 |
| T2 | 16-bit | `CMP <Rn>, <Rm>` — both low |
| T3 | 16-bit | `CMP <Rn>, <Rm>` — at least one high register |
| T2 | 32-bit | `CMP.W <Rn>, #<const>` — modified immediate |
| T3 | 32-bit | `CMP.W <Rn>, <Rm>{, <shift>}` |

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
    @ CMP demo: signed and unsigned comparisons of the same registers.
    mov     r0, #-1                @ 0xFFFFFFFF
    mov     r1, #1
    cmp     r0, r1                 @ unsigned: 0xFFFFFFFF >= 1, C=1
    bhs     unsigned_ge            @ taken (unsigned)
unsigned_ge:
    cmp     r0, r1                 @ signed: -1 < 1, N=1, V=0 -> N != V
    blt     signed_lt              @ taken (signed)
signed_lt:
    cmp     r0, #0xFF              @ immediate compare against 0x000000FF
loop:
    b   loop
```

**Walkthrough:**

1. First `cmp r0, r1` + `BHS` — the *unsigned* test fires because `0xFFFFFFFF` is the largest unsigned value.
2. Second `cmp r0, r1` + `BLT` — the *signed* test fires because as a signed value, `r0 = -1 < 1`. Same registers, opposite branch — choosing the right condition mnemonic is the whole game.
3. `cmp r0, #0xFF` — immediate form; the assembler picks T1 (8-bit imm) when it fits, otherwise T2.

This is the part that bites people: `CMP` C-flag means "no borrow". So `BCS`/`BHS` is taken when **`Rn >= Rm` unsigned**, which is the opposite of x86's CF after `cmp`. Easy to flip by accident.

## See also

- [SUB](SUB.md) — same arithmetic, with destination written.
- [CMN](CMN.md) — compares against `-Rm` (i.e. `Rn + Rm`); useful when comparing to a small negative constant.
- [TST](TST.md), [TEQ](TEQ.md) — logical test cousins.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.27 — *CMP (immediate)* and §C2.4.28 — *CMP (register)*.
