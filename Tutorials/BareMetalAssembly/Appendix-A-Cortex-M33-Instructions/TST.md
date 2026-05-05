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

## See also

- [AND](AND.md) — same operation, but writes the result.
- [TEQ](TEQ.md) — XOR-based equality test.
- [CMP](CMP.md) — subtraction-based comparison.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.197 — *TST (immediate)* and §C2.4.198 — *TST (register)*.
