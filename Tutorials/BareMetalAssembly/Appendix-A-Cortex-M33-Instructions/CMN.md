# CMN — compare negative: add and set flags, discard the result

## Class & availability

- **Class:** Compare
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
CMN{<cond>} <Rn>, <Rm>{, <shift>}
CMN{<cond>} <Rn>, #<const>
```

`CMN Rn, op2` is `ADDS` with the result discarded. Equivalent in flag-effect to `CMP Rn, -op2` — handy for comparing against small negative values that wouldn't fit as a `CMP` immediate.

**When you'd actually use this** is **comparing against a small negative immediate** — `cmn r0, #1` answers "is r0 == -1?" in one instruction, while `cmp r0, #-1` would have to materialise `0xFFFFFFFF` into a scratch register first. It's also handy when you've already negated an offset and want to compare without a separate `RSB`. In hand-written code it's rare, but compilers reach for it whenever a comparison constant is small and negative.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rn>` | left-hand value | R0–R12, LR; R0–R7 (T1) |
| `<Rm>` | right-hand register | R0–R12, LR |
| `#<const>` | immediate | Thumb-2 modified immediate (T2) |
| `<shift>` | optional shift on `<Rm>` | `LSL`/`LSR`/`ASR`/`ROR` #1..31, or `RRX` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    (result, carry, overflow) = AddWithCarry(R[n], operand2, '0')
    APSR.N = result<31>
    APSR.Z = IsZeroBit(result)
    APSR.C = carry         @ unsigned overflow of Rn + operand2
    APSR.V = overflow      @ signed overflow of Rn + operand2
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | ✓ | – |

Always.

## When to reach for CMN

- Comparing a register to a small negative immediate: `CMP r0, #-4` is invalid, but `CMN r0, #4` does the same job (sets flags as if you computed `r0 - (-4) = r0 + 4`, and then you branch on the result you actually want).
- Z is set ⇔ `Rn + Rm == 0` ⇔ `Rn == -Rm`.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `CMN <Rn>, <Rm>` — both low registers |
| T2 | 32-bit | `CMN.W <Rn>, #<const>` — modified immediate |
| T3 | 32-bit | `CMN.W <Rn>, <Rm>{, <shift>}` |

## Exceptions / faults

- (none).

## Example

### Example 1 — compare against a small negative

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ CMN demo: compare against -8 without burning a register on the constant.
    mov     r0, #-8                @ 0xFFFFFFF8
    cmn     r0, #8                 @ r0 + 8 = 0 -> Z=1, so r0 == -8
    beq     equal_minus_eight
    @ ... fall-through
equal_minus_eight:
    mov     r1, #5
    cmn     r1, #3                 @ 5 + 3 = 8: Z=0, N=0, no overflow
loop:
    b   loop
```

**Walkthrough:**

1. `cmn r0, #8` followed by `BEQ` — fires when `r0 == -8`. Equivalent to the rejected `CMP r0, #-8`, but legal because the immediate field encodes the positive 8.
2. The second `cmn` is a pure flag-setter: gives you N/Z/C/V as if you had executed `ADDS rX, r1, #3`, but no register is clobbered.

This is the part that bites people: the **C flag of `CMN` is opposite-sense to the C flag of `CMP`**. After `CMN` C means "addition overflowed unsigned", whereas after `CMP` C means "no borrow". Don't blindly translate `BCS` between them.

### Example 2 — test for the −1 sentinel

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ A linked-list "next" index of -1 means "end of list".
    mov     r0, #-1                @ pretend we just dequeued the sentinel
    cmn     r0, #1                 @ r0 + 1 == 0  =>  Z=1 iff r0 == -1
    beq     end_of_list
    @ ... process index ...
end_of_list:
loop:
    b   loop
```

**Walkthrough:** `CMN r0, #1` sets Z when `r0 + 1 == 0`, i.e. when `r0 == -1`. Doing the same with `CMP` would need `mov r1, #-1; cmp r0, r1` — two instructions and a scratch register — because `-1` doesn't fit as a `CMP` immediate.

## See also

- [ADD](ADD.md) — same arithmetic, with destination written.
- [CMP](CMP.md) — subtraction-based compare; the partner of `CMN`.
- [TST](TST.md), [TEQ](TEQ.md) — logical test cousins.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.25 — *CMN (immediate)* and §C2.4.26 — *CMN (register)*.
