# TST — test bits: AND that updates flags only

## Class & availability

- **Class:** Compare (logical test)
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
TST{<cond>} <Rn>, <Rm>{, <shift>}
TST{<cond>} <Rn>, #<const>
```

`TST` is `ANDS` with the result thrown away — flags get set, no register is written. There is no `S` suffix because flag-setting is the whole point.

**When you'd actually use this** is **testing whether one or more bits are set** — `tst r0, #FLAG; bne flag_set` is the canonical "is this flag bit on?" check, in one instruction with no scratch register. It's `ANDS` with the AND result thrown away, so flags update but `r0` stays clean for later use. Reach for it in interrupt status polls (`tst r0, #PENDING_MASK`), feature-bit tests, and anywhere you'd otherwise be tempted to write `and rN, r0, #FLAG; cmp rN, #0` — `TST` collapses those two into one.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rn>` | source register | R0–R12, LR (32-bit form); R0–R7 (T1) |
| `<Rm>` | second source register | R0–R12, LR |
| `#<const>` | modified immediate | Thumb-2 modified immediate |
| `<shift>` | optional shift on `<Rm>` | `LSL`/`LSR`/`ASR`/`ROR` #1..31, or `RRX` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    (shifted, carry) = Shift_C(R[m], shift_t, shift_n, APSR.C)
    result = R[n] AND shifted
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

Always updates N, Z, C (no `S` suffix to opt out).

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `TST <Rn>, <Rm>` — low registers |
| T2 | 32-bit | `TST.W <Rn>, #<const>` — immediate |
| T3 | 32-bit | `TST.W <Rn>, <Rm>{, <shift>}` — register with shift |

## Exceptions / faults

- (none).

## Example

### Example 1 — branch on a bit

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ TST demo: branch when bit 7 of r0 is set.
    ldr     r0, =0xDEADBEEF
    tst     r0, #0x80              @ Z = (r0 & 0x80) == 0
    beq     bit7_clear             @ branch if bit 7 was clear
    @ ... bit 7 was set, fall through
bit7_clear:
    tst     r0, #0xFF              @ also valid: Z = (low byte == 0)
loop:
    b   loop
```

**Walkthrough:**

1. `tst r0, #0x80` — checks whether bit 7 is set. If clear, the AND is zero and `Z=1`; `BEQ` then takes the branch. This is the canonical "is this bit set?" idiom.
2. `tst r0, #0xFF` — quick "is the low byte all zero?" test, with no scratch register needed.

This is the part that bites people: `TST` and `BEQ` mean "bit was **clear**", `TST` and `BNE` means "at least one tested bit was set".

### Example 2 — wait for a READY flag

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Spin until bit 3 (READY) of a peripheral STATUS word is set.
    ldr     r1, =0x40000008        @ pretend STATUS register address
wait_ready:
    ldr     r0, [r1]
    tst     r0, #(1 << 3)          @ Z=0 iff READY is set
    beq     wait_ready             @ branch back while READY is clear
    @ ... peripheral is ready ...
loop:
    b   loop
```

**Walkthrough:** `TST` ANDs `r0` with the single-bit mask, sets Z from the result, and discards the AND output. `BEQ` keeps spinning while the bit is clear; the loop falls through the moment READY appears. `r0` retains the full status word, so you can immediately inspect other flags after exiting the spin.

## See also

- [AND](AND.md) — same operation, but writes the result.
- [TEQ](TEQ.md) — XOR-based equality test.
- [CMP](CMP.md) — subtraction-based comparison.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.197 — *TST (immediate)* and §C2.4.198 — *TST (register)*.
