# LDRB — load a byte from memory, zero-extended into a 32-bit register

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
LDRB{<cond>}  <Rt>, [<Rn>{, #<imm>}]
LDRB{<cond>}  <Rt>, [<Rn>, <Rm>{, LSL #<n>}]
LDRB{<cond>}  <Rt>, [<Rn>, #<imm>]!
LDRB{<cond>}  <Rt>, [<Rn>], #<imm>
LDRB{<cond>}  <Rt>, <label>
```

Reads one byte and zero-extends it. For sign-extension use [`LDRSB`](LDRSB.md).

## Operands

| Field   | Type                 | Constraints                                              |
|---------|----------------------|----------------------------------------------------------|
| `<Rt>`  | destination register | R0–R14. PC not allowed.                                  |
| `<Rn>`  | base register        | R0–R15.                                                  |
| `<Rm>`  | index register       | R0–R12.                                                  |
| `<imm>` | offset               | T1: imm5 (0–31). T2/T3: imm12/imm8 with sign and writeback. |

## Operation (pseudocode)

```text
offset_addr = R[n] + offset;
address     = (index) ? offset_addr : R[n];
R[t]        = ZeroExtend(MemU[address, 1], 32);
if wback then R[n] = offset_addr;
@ Flags unchanged.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form                                                          |
|---------|--------|---------------------------------------------------------------|
| T1      | 16-bit | `LDRB <Rt>, [<Rn>, #<imm5>]` — low regs only.                 |
| T2      | 16-bit | `LDRB <Rt>, [<Rn>, <Rm>]` — register offset, low regs only.   |
| T2 (32) | 32-bit | `LDRB.W <Rt>, [<Rn>, #<imm12>]` — positive offset 0..4095.    |
| T3 (32) | 32-bit | `LDRB.W <Rt>, [<Rn>, #±<imm8>]{!}` / post-indexed.            |
| T2 (32) | 32-bit | `LDRB.W <Rt>, [<Rn>, <Rm>{, LSL #0–3}]`.                      |
| T1 lit  | 32-bit | `LDRB.W <Rt>, <label>` — PC-relative.                         |

## Exceptions / faults

- BusFault, MemManage as for [`LDR`](LDR.md).
- Byte accesses are inherently aligned, so no UNALIGNED fault.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ LDRB demo: walking a C-string and reading a status register byte.
    ldr     r0, =message
    ldrb    r1, [r0]                @ first char, zero-extended
    ldrb    r2, [r0, #1]            @ second char
    ldrb    r3, [r0], #1            @ post-index: r3 = *r0; r0++
    movs    r4, #2
    ldrb    r5, [r0, r4]            @ register offset
loop:
    b       loop

    .align  2
message:
    .asciz  "Hi!"
```

**Walkthrough:**

1. `ldrb r1, [r0]` — reads `'H'` (0x48) and zero-extends to 0x00000048. This is the part that bites people moving from x86: the upper 24 bits are *guaranteed zero*, never garbage.
2. `ldrb r2, [r0, #1]` — `'i'` from offset 1.
3. `ldrb r3, [r0], #1` — post-indexed: load then bump base. Idiomatic for `*p++` byte loops.
4. `ldrb r5, [r0, r4]` — uses a register-held offset, useful for table indexing where the offset is computed.

## See also

- [LDRSB](LDRSB.md) — sign-extending byte load (for `int8_t`).
- [LDRH](LDRH.md) / [LDRSH](LDRSH.md) — half-word variants.
- [LDR](LDR.md) — full word load.
- [STRB](STRB.md) — symmetric byte store.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.41–C2.4.43 — *LDRB (immediate/literal/register)*.
