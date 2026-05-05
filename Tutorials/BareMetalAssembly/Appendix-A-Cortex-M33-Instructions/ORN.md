# ORN — bitwise OR with the NOT of operand2

## Class & availability

- **Class:** Logical
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
ORN{S}{<cond>} {<Rd>,} <Rn>, <Rm>{, <shift>}
ORN{S}{<cond>} {<Rd>,} <Rn>, #<const>
```

`Rd = Rn OR (NOT operand2)`. The OR-side cousin of `BIC`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR |
| `<Rn>` | first source register | R0–R12, LR; **must not be PC** |
| `<Rm>` | second source register | R0–R12, LR |
| `#<const>` | modified immediate | Thumb-2 modified immediate |
| `<shift>` | optional shift on `<Rm>` | `LSL`/`LSR`/`ASR`/`ROR` #1..31, or `RRX` |

If `Rn` is `PC` (`0b1111`), the encoding becomes `MVN` instead — the assembler will pick `MVN` for you.

## Operation (pseudocode)

```text
if ConditionPassed() then
    (shifted, carry) = Shift_C(R[m], shift_t, shift_n, APSR.C)
    result = R[n] OR NOT(shifted)
    R[d] = result
    if S == '1' then
        APSR.N = result<31>
        APSR.Z = IsZeroBit(result)
        APSR.C = carry
        @ APSR.V unchanged
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | – | – |

`ORNS` only. C is the shifter carry-out.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `ORN{S} <Rd>, <Rn>, #<const>` — immediate. **No 16-bit form.** |
| T1 | 32-bit | `ORN{S} <Rd>, <Rn>, <Rm>{, <shift>}` — register. **No 16-bit form.** |

`ORN` is **Thumb-2 (32-bit) only** — there is no 16-bit Thumb encoding.

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
    @ ORN demo: force the high byte of a value to all ones (sign-extend-ish).
    ldr     r0, =0x00ABCDEF
    mov     r1, #0x00FFFFFF
    orn     r2, r0, r1             @ r2 = r0 | ~0x00FFFFFF = 0xFFABCDEF
    @ Equivalent without ORN: orr r2, r0, #0xFF000000 — only works because
    @ 0xFF000000 is a valid Thumb-2 modified immediate. ORN saves you when
    @ the inverted constant fits but the direct one doesn't.
loop:
    b   loop
```

**Walkthrough:**

1. `mov r1, #0x00FFFFFF` — load a mask whose bits we want to **leave alone** (well, leave-as-`Rn`). `~r1` is `0xFF000000`.
2. `orn r2, r0, r1` — sets exactly those high 8 bits in `r0`. Result: `0xFFABCDEF`.
3. The real win: when the *inverted* form of an immediate is encodable as a Thumb-2 modified immediate but the direct form isn't, `ORN #x` succeeds where `ORR #~x` would have to spill to a literal pool.

## See also

- [ORR](ORR.md) — OR without the NOT.
- [BIC](BIC.md) — `AND NOT`, the clear-bits cousin.
- [MVN](MVN.md) — same as `ORN` with `Rn = PC`/zero; the canonical "load NOT-immediate".

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.115 — *ORN (immediate)* and §C2.4.116 — *ORN (register)*.
