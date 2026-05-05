# EOR — bitwise exclusive-OR (XOR) of two values

## Class & availability

- **Class:** Logical
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
EOR{S}{<cond>} {<Rd>,} <Rn>, <Rm>{, <shift>}
EOR{S}{<cond>} {<Rd>,} <Rn>, #<const>
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR (32-bit forms); R0–R7 (T1) |
| `<Rn>` | first source register | same as `<Rd>` |
| `<Rm>` | second source register | R0–R12, LR |
| `#<const>` | modified immediate | Thumb-2 modified immediate |
| `<shift>` | optional shift on `<Rm>` | `LSL`/`LSR`/`ASR`/`ROR` #1..31, or `RRX` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    (shifted, carry) = Shift_C(R[m], shift_t, shift_n, APSR.C)
    result = R[n] EOR shifted
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

Flags only update with `EORS`. C is the shifter carry-out.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `EORS <Rdn>, <Rm>` — low registers, always sets flags |
| T2 | 32-bit | `EOR{S}.W <Rd>, <Rn>, #<const>` — immediate |
| T3 | 32-bit | `EOR{S}.W <Rd>, <Rn>, <Rm>{, <shift>}` — register with shift |

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
    @ EOR demo: toggle a bit, zero a register, and check parity-ish equality.
    ldr     r0, =0xDEADBEEF
    eor     r1, r0, #0x00000001    @ toggle bit 0 -> 0xDEADBEEE
    eor     r2, r1, r1             @ classic "zero a register" idiom: r2 = 0
    ldr     r3, =0xDEADBEEF
    eors    r4, r0, r3             @ r4 = 0, sets Z=1 (so r0 == r3)
loop:
    b   loop
```

**Walkthrough:**

1. `eor r1, r0, #0x00000001` — flips bit 0. XOR is the standard "toggle these bits" tool.
2. `eor r2, r1, r1` — XOR-with-self always yields zero. Cheaper than `mov r2, #0` on some pipelines and a frequent compiler idiom.
3. `eors r4, r0, r3` — if `r0 == r3` the result is 0 and Z is set. This is exactly what `TEQ` does, just keeping the result.

## See also

- [TEQ](TEQ.md) — `EOR` with flags only, result discarded.
- [AND](AND.md), [ORR](ORR.md), [BIC](BIC.md) — the rest of the logical family.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.39 — *EOR (immediate)* and §C2.4.40 — *EOR (register)*.
