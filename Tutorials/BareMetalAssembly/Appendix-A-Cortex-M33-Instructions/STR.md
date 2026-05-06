# STR — store a 32-bit word from a register to memory

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
STR{<cond>}  <Rt>, [<Rn>{, #<imm>}]              @ immediate offset
STR{<cond>}  <Rt>, [<Rn>, <Rm>{, LSL #<n>}]      @ register / scaled offset
STR{<cond>}  <Rt>, [<Rn>, #<imm>]!               @ pre-indexed
STR{<cond>}  <Rt>, [<Rn>], #<imm>                @ post-indexed
```

The symmetric partner of [`LDR`](LDR.md). No PC-relative or `STR =const` forms — stores cannot use a literal pool.

**When you'd actually use this**: any time you write a 32-bit value to memory — poking an MMIO peripheral register like `UART->TXDATA` or a GPIO `OUT_SET`/`OUT_CLR` register, pushing a word into a software FIFO ring buffer, or populating a `uint32_t` field in a struct. The address must be word-aligned for Device/Strongly-Ordered memory and (by default) for Normal memory too — peripheral registers in particular will fault hard on a misaligned `STR`. Without `STR` you'd have to fake a 32-bit write with four `STRB`s, which is both slower and wrong for MMIO (peripherals expect a single 32-bit bus transaction, not four byte ones).

## Operands

| Field   | Type            | Constraints                                                              |
|---------|-----------------|--------------------------------------------------------------------------|
| `<Rt>`  | source register | R0–R14. PC not allowed.                                                  |
| `<Rn>`  | base register   | R0–R13 (SP). PC not allowed as base for stores.                          |
| `<Rm>`  | index register  | R0–R12.                                                                  |
| `<imm>` | offset          | T1: imm5 ×4 (0–124). T3: imm12 (0–4095). T4: ±imm8 with writeback.       |
| `LSL #<n>` | shift        | 0..3.                                                                    |

## Operation (pseudocode)

```text
offset_addr = (add) ? R[n] + offset : R[n] - offset;
address     = (index) ? offset_addr : R[n];
MemU[address, 4] = R[t];
if wback then R[n] = offset_addr;
@ Flags unchanged.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form                                                              |
|---------|--------|-------------------------------------------------------------------|
| T1      | 16-bit | `STR <Rt>, [<Rn>, #<imm5*4>]` — low regs only.                    |
| T2      | 16-bit | `STR <Rt>, [SP, #<imm8*4>]` — SP-relative.                        |
| T3 (32) | 32-bit | `STR.W <Rt>, [<Rn>, #<imm12>]` — positive offset.                 |
| T4 (32) | 32-bit | `STR.W <Rt>, [<Rn>, #±<imm8>]{!}` / post-indexed.                 |
| T2 (32) | 32-bit | `STR.W <Rt>, [<Rn>, <Rm>{, LSL #0–3}]`.                           |

## Exceptions / faults

- **BusFault** on bus error.
- **MemManage** on MPU access denied (e.g. write to read-only region).
- **UsageFault (UNALIGNED)** if `CCR.UNALIGN_TRP = 1` and address not word-aligned. Strongly-Ordered/Device memory always faults on unaligned word stores.
- **SecureFault** for cross-domain stores (Security extension).

## Example

### Example 1 — Indexed and writeback addressing modes

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ STR demo: write to a buffer with each addressing mode.
    ldr     r0, =buffer
    movs    r1, #0xAA
    str     r1, [r0]                @ buffer[0] = 0xAA
    str     r1, [r0, #4]            @ buffer[1] = 0xAA
    movs    r2, #2
    str     r1, [r0, r2, lsl #2]    @ buffer[r2] (scaled by 4)
    str     r1, [r0, #8]!           @ pre-index: r0 += 8; *r0 = r1
    str     r1, [r0], #4            @ post-index: *r0 = r1; r0 += 4
loop:
    b       loop

    .data
    .align  2
buffer:
    .space  64
```

**Walkthrough:**

1. `str r1, [r0]` — writes 0xAA to `buffer[0]`.
2. `str r1, [r0, #4]` — writes the next word at offset 4.
3. `str r1, [r0, r2, lsl #2]` — `r2` is a word index, `lsl #2` scales by 4 — exactly how a C compiler addresses `buf[i]` for a `uint32_t[]`.
4. `str r1, [r0, #8]!` — pre-indexed: bump base first, then store. The base register is updated permanently.
5. `str r1, [r0], #4` — post-indexed: store first, advance base. Idiomatic for `*p++ = v` write loops.

### Example 2 — Ring-buffer enqueue with mask wrap

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Enqueue r3 into a 16-slot uint32_t ring buffer.
    ldr     r0, =ring          @ base of the ring (16 words)
    ldr     r1, =ring_head     @ &head (uint32_t index)
    ldr     r2, [r1]           @ head
    movw    r3, #0xC0DE        @ value to enqueue
    str     r3, [r0, r2, lsl #2]   @ ring[head] = value
    adds    r2, r2, #1
    and     r2, r2, #0x0F      @ head = (head + 1) & 15
    str     r2, [r1]           @ commit new head
loop:
    b       loop

    .data
    .align  2
ring:       .space  64
ring_head:  .word   0
```

**Walkthrough:**

1. `str r3, [r0, r2, lsl #2]` — scaled register offset: `r2` is a word index, `lsl #2` turns it into a byte offset.
2. The mask `& 15` cheaply wraps the index when the ring has a power-of-two size — no compare-and-branch needed.
3. The final `str r2, [r1]` commits the updated head pointer back to memory; in a real driver this would be paired with a `DMB` so a consumer on another exception level sees the data write before the head update.

## See also

- [LDR](LDR.md) — symmetric load.
- [STRB](STRB.md) / [STRH](STRH.md) — narrower stores.
- [STRD](STRD.md) — store two words.
- [STM](STM.md) — store multiple registers.
- [PUSH](PUSH.md) — store-multiple with SP writeback.
- [STL](STL.md) — release-semantic word store (v8-M).
- [STREX](STREX.md) — exclusive store for atomics.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.180–C2.4.182 — *STR (immediate/register)*.
