# SBC — subtract with borrow; the building block of multi-word subtraction

## Class & availability

- **Class:** Arithmetic
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SBC{S}{<cond>} {<Rd>,} <Rn>, #<imm>
SBC{S}{<cond>} {<Rd>,} <Rn>, <Rm>{, <shift>}
```

`Rd = Rn − operand2 − (1 − APSR.C)`. In words: subtract, then subtract one more if there was a previous borrow (C=0).

**When you'd actually use this**: SBC is the second half of any wide subtraction the same way ADC is the second half of a wide add — 64-bit subtract, big-int diff in crypto, multi-precision counters. The key gotcha is that ARM's C-flag is *inverted* on subtract: `C=0` means "borrow occurred", `C=1` means "no borrow". So the leading instruction must be `SUBS` (not plain `SUB`), and nothing flag-touching is allowed between the `SUBS` and the `SBC`. There is no `RSC` on Armv8-M, so wide reverse-subtract has to be open-coded as `RSBS` + `SBC`-with-zero or rearranged into a normal `SUBS`/`SBC` chain.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | T1: `R0`–`R7`. T2: `R0`–`R12`. |
| `<Rn>` | minuend | same set as `<Rd>` |
| `<Rm>` | subtrahend register | any low/high register in 32-bit form |
| `#<imm>` | immediate | T2 only: 12-bit modified immediate |
| `<shift>` | optional shift on `<Rm>` | `LSL`/`LSR`/`ASR`/`ROR` #0–31, or `RRX` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    (result, carry, overflow) = AddWithCarry(R[n], NOT(operand2), APSR.C)
    R[d] = result
    if S == '1' then
        APSR.N = result<31>
        APSR.Z = IsZeroBit(result)
        APSR.C = carry          // C = NOT borrow-out
        APSR.V = overflow
```

Same trick as `SUB`: ARM defines subtract as `Rn + ~op2 + Cin`, where `Cin = APSR.C`. So when C=1 (no prior borrow) you get a plain subtract; when C=0 you also subtract 1 to propagate the borrow.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | ✓ | – |

Only with the `S` suffix. `SBC` always *reads* C as the borrow-in.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `SBCS Rdn, Rm` (low regs) |
| T2 | 32-bit | `SBC{S}.W Rd, Rn, Rm{, shift}` |
| T2 | 32-bit | `SBC{S}.W Rd, Rn, #<modified imm>` |

## Exceptions / faults

- (none).

## Example

### Example 1 — 64-bit subtract with borrow propagation

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SBC demo: 64-bit subtract of (r1:r0) - (r3:r2) -> (r5:r4)
    ldr     r0, =0x00000010     @ low word of A
    ldr     r1, =0x00000002     @ high word of A
    ldr     r2, =0x00000020     @ low word of B  (bigger than A.lo)
    ldr     r3, =0x00000001     @ high word of B
    subs    r4, r0, r2          @ low subtract, clears C (borrow)
    sbc     r5, r1, r3          @ high subtract picks up the borrow
loop:
    b       loop
```

**Walkthrough:**

1. `subs r4, r0, r2` — `0x10 − 0x20` underflows; C is cleared, signalling a borrow.
2. `sbc r5, r1, r3` — `r1 − r3 − borrow = 2 − 1 − 1 = 0`. Without `SBC` we'd silently lose the borrow and get 1 instead of 0.

### Example 2 — 64-bit decrement of (r1:r0) by 1

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global reset_handler
    .thumb_func
reset_handler:
    ldr     r0, =0x00000000     @ counter.lo (about to underflow)
    ldr     r1, =0x00000001     @ counter.hi
    subs    r0, r0, #1          @ low - 1: borrow occurs, C=0
    sbc     r1, r1, #0          @ propagate the borrow into the high half
loop:
    b       loop
```

**Walkthrough:**

1. `subs r0, r0, #1` — `0 − 1` underflows; the result wraps to `0xFFFFFFFF` and APSR.C clears (remember: C=0 means borrow on ARM).
2. `sbc r1, r1, #0` — subtracts 0 plus the inverted borrow, i.e. effectively subtracts 1, taking the high half from 1 to 0. The 64-bit value goes from `0x100000000` down to `0xFFFFFFFF`.
3. Drop the `S` on the first line and the `SBC` will use stale flags — usually C=1 from some earlier instruction — and silently lose the borrow.

## See also

- [SUB](SUB.md) — the carry-less subtract that starts a multi-word chain
- [ADC](ADC.md) — the symmetric add-with-carry
- [RSB](RSB.md) — reverse subtract; `RSC` does not exist on Armv8-M

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.150 — *SBC (immediate)*, §C2.4.151 — *SBC (register)*.
