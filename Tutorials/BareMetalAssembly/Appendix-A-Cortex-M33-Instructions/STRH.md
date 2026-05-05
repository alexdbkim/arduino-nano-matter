# STRH — store the low half-word (16 bits) of a register to memory

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
STRH{<cond>}  <Rt>, [<Rn>{, #<imm>}]
STRH{<cond>}  <Rt>, [<Rn>, <Rm>{, LSL #<n>}]
STRH{<cond>}  <Rt>, [<Rn>, #<imm>]!
STRH{<cond>}  <Rt>, [<Rn>], #<imm>
```

Stores `R[t]<15:0>`. Address must be half-word aligned.

## Operands

| Field   | Type            | Constraints                                              |
|---------|-----------------|----------------------------------------------------------|
| `<Rt>`  | source register | R0–R14.                                                  |
| `<Rn>`  | base register   | R0–R13.                                                  |
| `<Rm>`  | index register  | R0–R12.                                                  |
| `<imm>` | offset          | T1: imm5 ×2 (0–62). T2/T3: imm12/imm8.                   |

## Operation (pseudocode)

```text
offset_addr = R[n] + offset;
address     = (index) ? offset_addr : R[n];
MemU[address, 2] = R[t]<15:0>;
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
| T1      | 16-bit | `STRH <Rt>, [<Rn>, #<imm5*2>]` — low regs only.            |
| T2      | 16-bit | `STRH <Rt>, [<Rn>, <Rm>]` — register offset, low regs only.|
| T2 (32) | 32-bit | `STRH.W <Rt>, [<Rn>, #<imm12>]`.                           |
| T3 (32) | 32-bit | `STRH.W <Rt>, [<Rn>, #±<imm8>]{!}` / post-indexed.         |
| T2 (32) | 32-bit | `STRH.W <Rt>, [<Rn>, <Rm>{, LSL #0–3}]`.                   |

## Exceptions / faults

- **UsageFault (UNALIGNED)** if `CCR.UNALIGN_TRP = 1` and the address is odd.
- BusFault / MemManage as usual.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ STRH demo: write 16-bit DAC values to a buffer.
    ldr     r0, =dac_buffer
    movw    r1, #0x1234
    strh    r1, [r0]                @ dac_buffer[0] = 0x1234
    movw    r2, #0xBEEF
    strh    r2, [r0, #2]            @ dac_buffer[1]
    movs    r3, #2                  @ index
    strh    r1, [r0, r3, lsl #1]    @ scaled: r0 + r3*2
    strh    r2, [r0], #2            @ post-indexed, advance r0
loop:
    b       loop

    .data
    .align  2
dac_buffer:
    .space  32
```

**Walkthrough:**

1. `strh r1, [r0]` — writes the low 16 bits of R1 (0x1234). The upper 16 bits of R1 are ignored.
2. `strh r2, [r0, r3, lsl #1]` — typical `uint16_t[]` indexed write: `lsl #1` scales the index by 2.
3. `strh r2, [r0], #2` — post-indexed streaming write, the C-equivalent of `*p++ = v;` for a `uint16_t *p`.

## See also

- [LDRH](LDRH.md) / [LDRSH](LDRSH.md) — companion half-word loads.
- [STRB](STRB.md) — byte store.
- [STR](STR.md) — full word store.
- [STLH](STLH.md) — release-semantic half-word store (v8-M).

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.176–C2.4.178 — *STRH (immediate/register)*.
