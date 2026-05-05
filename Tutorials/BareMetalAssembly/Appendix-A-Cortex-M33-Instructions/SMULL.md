# SMULL — signed 32×32 → 64-bit multiply

## Class & availability

- **Class:** Multiply (arithmetic)
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMULL{<cond>} <RdLo>, <RdHi>, <Rn>, <Rm>
```

`RdHi:RdLo = SignExtend(Rn) × SignExtend(Rm)` — full 64-bit signed product split across two registers.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<RdLo>` | low 32 bits of product | `R0`–`R12` |
| `<RdHi>` | high 32 bits of product | `R0`–`R12`, must differ from `<RdLo>` |
| `<Rn>` | first factor (signed) | `R0`–`R12` |
| `<Rm>` | second factor (signed) | `R0`–`R12` |

**Operand order:** `SMULL RdLo, RdHi, Rn, Rm` — low first, then high. `RdLo == RdHi` is UNPREDICTABLE.

## Operation (pseudocode)

```text
if ConditionPassed() then
    result = SInt(R[n]) * SInt(R[m])    // 64-bit signed product
    R[dHi] = result<63:32>
    R[dLo] = result<31:0>
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never on Armv8-M.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMULL RdLo, RdHi, Rn, Rm` (32-bit only) |

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
    @ SMULL demo: signed 64-bit product, then arithmetic-shift back to Q16.16
    ldr     r0, =-1500          @ a signed value
    ldr     r1, =0x00018000     @ 1.5 in Q16.16
    smull   r2, r3, r0, r1      @ r3:r2 = a * 1.5  (signed, 64-bit)
    lsrs    r2, r2, #16
    orr     r2, r2, r3, lsl #16 @ r2 = (a * 1.5) >> 16 (arith semantics in r3)
    @ if you only need the high half:
    smull   r4, r5, r0, r1
    @ r5 holds the sign-correct high 32 bits, e.g. for a 32-bit overflow check
loop:
    b       loop
```

**Walkthrough:**

1. `smull r2, r3, r0, r1` — `−1500 × 0x00018000 = −98304000`. As a 64-bit signed value the high word is sign-extended (all 1s for a negative result); UMULL would have given a positive 64-bit answer instead.
2. The shift sequence reconstructs the 32-bit Q16.16 result; in production code you'd inspect `r3` separately to detect overflow.

## See also

- [UMULL](UMULL.md) — the unsigned counterpart
- [SMLAL](SMLAL.md) — signed multiply-accumulate into a 64-bit pair
- [MUL](MUL.md) — only the low 32 bits (signed = unsigned at that width)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.180 — *SMULL*.
