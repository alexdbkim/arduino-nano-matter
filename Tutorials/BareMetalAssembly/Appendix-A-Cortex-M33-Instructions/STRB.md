# STRB — store the low byte of a register to memory

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
STRB{<cond>}  <Rt>, [<Rn>{, #<imm>}]
STRB{<cond>}  <Rt>, [<Rn>, <Rm>{, LSL #<n>}]
STRB{<cond>}  <Rt>, [<Rn>, #<imm>]!
STRB{<cond>}  <Rt>, [<Rn>], #<imm>
```

Stores `R[t]<7:0>`. Bits [31:8] of the register are ignored — there is no signed/unsigned distinction on stores.

## Operands

| Field   | Type            | Constraints                                              |
|---------|-----------------|----------------------------------------------------------|
| `<Rt>`  | source register | R0–R14.                                                  |
| `<Rn>`  | base register   | R0–R13.                                                  |
| `<Rm>`  | index register  | R0–R12.                                                  |
| `<imm>` | offset          | T1: imm5 (0–31). T2/T3: imm12/imm8 with sign.            |

## Operation (pseudocode)

```text
offset_addr = R[n] + offset;
address     = (index) ? offset_addr : R[n];
MemU[address, 1] = R[t]<7:0>;
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
| T1      | 16-bit | `STRB <Rt>, [<Rn>, #<imm5>]` — low regs only.              |
| T2      | 16-bit | `STRB <Rt>, [<Rn>, <Rm>]` — register offset, low regs only.|
| T2 (32) | 32-bit | `STRB.W <Rt>, [<Rn>, #<imm12>]`.                           |
| T3 (32) | 32-bit | `STRB.W <Rt>, [<Rn>, #±<imm8>]{!}` / post-indexed.         |
| T2 (32) | 32-bit | `STRB.W <Rt>, [<Rn>, <Rm>{, LSL #0–3}]`.                   |

## Exceptions / faults

- BusFault / MemManage as for [`STR`](STR.md). Byte stores are inherently aligned (no UNALIGNED fault).

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ STRB demo: build a small string in RAM and emit a UART byte.
    ldr     r0, =buffer
    movs    r1, #'H'
    strb    r1, [r0]                @ buffer[0] = 'H'
    movs    r1, #'i'
    strb    r1, [r0, #1]            @ buffer[1] = 'i'
    movs    r1, #0
    strb    r1, [r0, #2]            @ NUL terminator
    movs    r2, #'!'
    strb    r2, [r0], #1            @ post-indexed write, advance r0
loop:
    b       loop

    .data
    .align  2
buffer:
    .space  16
```

**Walkthrough:**

1. `strb r1, [r0]` — writes the low byte of R1 ('H') to `buffer[0]`. Bits 8..31 of R1 are ignored.
2. The `'i'` and NUL stores complete a C string.
3. `strb r2, [r0], #1` — the post-indexed form is the natural shape of a `*p++ = byte;` loop. This is the part that bites people: signed/unsigned doesn't enter into stores, but the *value* you stash must fit in 8 bits or you'll silently truncate.

## See also

- [LDRB](LDRB.md) / [LDRSB](LDRSB.md) — companion byte loads.
- [STRH](STRH.md) — half-word store.
- [STR](STR.md) — full word store.
- [STLB](STLB.md) — release-semantic byte store (v8-M).

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.171–C2.4.173 — *STRB (immediate/register)*.
