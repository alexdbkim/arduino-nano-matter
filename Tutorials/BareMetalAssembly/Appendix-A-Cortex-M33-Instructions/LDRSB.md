# LDRSB — load a signed byte from memory, sign-extended to 32 bits

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
LDRSB{<cond>}  <Rt>, [<Rn>{, #<imm>}]
LDRSB{<cond>}  <Rt>, [<Rn>, <Rm>{, LSL #<n>}]
LDRSB{<cond>}  <Rt>, [<Rn>, #<imm>]!
LDRSB{<cond>}  <Rt>, [<Rn>], #<imm>
LDRSB{<cond>}  <Rt>, <label>
```

Reads one byte and **sign-extends** bit 7 across the upper 24 bits. The natural way to load `int8_t`.

## Operands

| Field   | Type                 | Constraints                       |
|---------|----------------------|-----------------------------------|
| `<Rt>`  | destination register | R0–R14.                           |
| `<Rn>`  | base register        | R0–R15.                           |
| `<Rm>`  | index register       | R0–R12.                           |
| `<imm>` | offset               | T1/T2: imm12 / imm8 with sign.    |

## Operation (pseudocode)

```text
offset_addr = R[n] + offset;
address     = (index) ? offset_addr : R[n];
R[t]        = SignExtend(MemU[address, 1], 32);
if wback then R[n] = offset_addr;
@ Flags unchanged.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form                                                       |
|---------|--------|------------------------------------------------------------|
| T1      | 16-bit | `LDRSB <Rt>, [<Rn>, <Rm>]` — register offset, low regs only.|
| T1 (32) | 32-bit | `LDRSB.W <Rt>, [<Rn>, #<imm12>]`.                          |
| T2 (32) | 32-bit | `LDRSB.W <Rt>, [<Rn>, #±<imm8>]{!}` / post-indexed.        |
| T2 (32) | 32-bit | `LDRSB.W <Rt>, [<Rn>, <Rm>{, LSL #0–3}]`.                  |
| T1 lit  | 32-bit | `LDRSB.W <Rt>, <label>`.                                   |

There is **no** 16-bit immediate-offset form for `LDRSB`; immediate-offset uses are always 32-bit.

## Exceptions / faults

- BusFault / MemManage as for [`LDR`](LDR.md). Single-byte accesses do not raise UNALIGNED.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ LDRSB demo: read int8_t temperature deltas from a buffer.
    ldr     r0, =deltas
    ldrsb   r1, [r0]                @ r1 = (int32_t)*((int8_t*)r0)
    ldrsb   r2, [r0, #1]            @ r2 = sign-extended next byte
    movs    r3, #2
    ldrsb   r4, [r0, r3]            @ register-offset variant
    ldrsb   r5, [r0], #1            @ post-indexed *p++
loop:
    b       loop

    .align  2
deltas:
    .byte   -1, 127, -128, 0
```

**Walkthrough:**

1. `ldrsb r1, [r0]` — first byte is `-1` (0xFF). After sign-extension R1 = 0xFFFFFFFF (-1).
2. `ldrsb r2, [r0, #1]` — `127` (0x7F). Bit 7 is 0, so R2 = 0x0000007F.
3. `ldrsb r4, [r0, r3]` — `-128` (0x80). Bit 7 is 1, R4 = 0xFFFFFF80 (-128). This is the part that bites people: a plain `LDRB` here would yield 0x00000080 (+128).
4. `ldrsb r5, [r0], #1` — typical streaming pattern for signed byte arrays.

## See also

- [LDRB](LDRB.md) — zero-extending byte load (for `uint8_t`).
- [LDRSH](LDRSH.md) — sign-extending half-word load (for `int16_t`).
- [LDR](LDR.md) — full word load.
- [STRB](STRB.md) — byte store (no signed variant; sign doesn't matter on stores).

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.49–C2.4.50 — *LDRSB (immediate/literal/register)*.
