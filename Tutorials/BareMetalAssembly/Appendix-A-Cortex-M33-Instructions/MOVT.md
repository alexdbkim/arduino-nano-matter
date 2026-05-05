# MOVT — write a 16-bit immediate into the top half of a register, leaving the bottom half intact

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
MOVT  <Rd>, #<imm16>
```

Writes `imm16` to bits [31:16] of `<Rd>` and **preserves** bits [15:0]. The standard pair with [`MOVW`](MOVW.md) for 32-bit constants.

## Operands

| Field   | Type                 | Constraints                                |
|---------|----------------------|--------------------------------------------|
| `<Rd>`  | destination register | R0–R12, R14. SP and PC are forbidden.      |
| `<imm>` | immediate            | 0..65535 (16-bit unsigned, goes into top). |

## Operation (pseudocode)

```text
if ConditionPassed() then
    R[d]<31:16> = imm16;
    @ R[d]<15:0> unchanged.
    @ Flags unchanged.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

No flag-setting form exists.

## Encodings

| Variant | Width  | Form                                  |
|---------|--------|---------------------------------------|
| T1      | 32-bit | `MOVT <Rd>, #<imm16>` — only encoding.|

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
    @ MOVT demo: assemble a 32-bit address one half at a time.
    movw    r0, #0x1234             @ r0 = 0x00001234
    movt    r0, #0xABCD             @ r0 = 0xABCD1234
    @ MOVT alone — preserves the existing low half:
    movw    r1, #0x0001             @ r1 = 0x00000001
    movt    r1, #0xFFFF             @ r1 = 0xFFFF0001 (low half preserved)
    @ Loading the SCB->VTOR address (0xE000ED08) on EFR32MG24:
    movw    r2, #0xED08
    movt    r2, #0xE000             @ r2 = 0xE000ED08
loop:
    b   loop
```

**Walkthrough:**

1. `movw r0, #0x1234` — initialises R0 with the low half and clears the top half.
2. `movt r0, #0xABCD` — writes the top half *without* disturbing 0x1234. R0 is now 0xABCD1234.
3. `movw r1, #0x0001` / `movt r1, #0xFFFF` — proves MOVT does not zero the low half (compare with `MOVW`, which always zeros the high half). This is the part that bites people: doing two `MOVW`s and expecting a 32-bit value will **not** work.
4. `movw r2, #0xED08` / `movt r2, #0xE000` — canonical pattern for getting a peripheral or SCB address into a register.

## See also

- [MOVW](MOVW.md) — companion; sets the low half and clears the top.
- [MOV](MOV.md) — the assembler can synthesise `LDR Rd, =const` or `MOVW/MOVT` from `MOV`.
- [LDR](LDR.md) — `LDR Rd, =const` (literal pool) is the alternative for arbitrary 32-bit constants.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.72 — *MOVT*.
