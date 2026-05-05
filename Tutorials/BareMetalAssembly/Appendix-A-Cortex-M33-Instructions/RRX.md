# RRX — rotate right with extend (33-bit rotate through carry)

## Class & availability

- **Class:** Shift/Rotate
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
RRX{S}{<cond>} {<Rd>,} <Rm>
```

Rotate the 33-bit concatenation `{C : Rm}` right by exactly **one** position. The old C becomes the new bit 31; the old bit 0 becomes the new C (when `S` is set).

## The 33-bit rotate, drawn out

```
        before:                       after RRX:
       ┌─────────────── Rm ────────────────┐
   C   31 30  ...  1  0                          new C
   ┃   ┃                ┃                            ┃
   ┃   └────► used as ──► new bit 31 of Rd          ┃
   ┃                                                ┃
   └──── new bit 31 ────┐                           ┃
                        ▼                           ┃
   ┌──────────────── Rd ────────────────┐           ┃
   │ oldC | oldBit31 | oldBit30 | ... | oldBit1 │  ◄─ oldBit0 (= new C)
   └────────────────────────────────────────────┘

   In other words, every bit of Rm shifts right by one,
   bit 0 falls into C, and C drops in at bit 31.
```

There is no shift count operand — `RRX` always rotates by 1. For larger rotations, use [`ROR`](ROR.md).

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR |
| `<Rm>` | source register | R0–R12, LR |

## Operation (pseudocode)

```text
if ConditionPassed() then
    result<30:0> = R[m]<31:1>
    result<31>   = APSR.C
    new_carry    = R[m]<0>
    R[d] = result
    if S == '1' then
        APSR.N = result<31>          @ = old APSR.C
        APSR.Z = IsZeroBit(result)
        APSR.C = new_carry           @ = old R[m]<0>
        @ APSR.V unchanged
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | – | – |

`RRXS` only. With `S`, **N becomes the old C** and **C becomes the old bit 0** — useful and confusing in equal measure.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `RRX{S} <Rd>, <Rm>` — only form. **No 16-bit form.** |

`RRX` is also available as the shift kind on operand2 of any shift-capable instruction (e.g. `MOV r0, r1, RRX`, `ADD r2, r3, r4, RRX`). In that context it's encoded as `ROR #0`.

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
    @ RRX demo: 64-bit unsigned right shift by 1 across r1:r0 (low:high).
    @ Treat r1 = high word, r0 = low word.
    ldr     r1, =0x12345678        @ high
    ldr     r0, =0x9ABCDEF1        @ low (LSB = 1)
    lsrs    r1, r1, #1             @ shift high right; bit 0 of high lands in C
    rrx     r0, r0                 @ shift low right, pulling that C in at bit 31
    @ now r1:r0 = (original r1:r0) >> 1, exactly.
loop:
    b   loop
```

**Walkthrough:**

1. `lsrs r1, r1, #1` — shifts the high word right; the bit that falls off the bottom goes into C. `S` is required so that C captures it.
2. `rrx r0, r0` — shifts the low word right by one, dropping that captured C into bit 31. The combined effect is a clean 64-bit right shift.

This is the part that bites people: the `S`-suffix dance is mandatory. If you forget `LSRS` and write `LSR`, C still holds whatever it did before and `RRX` will rotate in the **wrong** bit. Multi-word shifts are a leading source of subtle bugs in hand-written assembler and crypto code.

## See also

- [ROR](ROR.md) — multi-bit rotate; `RRX` is morally `ROR #1` extended to 33 bits.
- [LSR](LSR.md), [ASR](ASR.md) — single-register right shifts that *feed* `RRX` for multi-word work.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.142 — *RRX*.
