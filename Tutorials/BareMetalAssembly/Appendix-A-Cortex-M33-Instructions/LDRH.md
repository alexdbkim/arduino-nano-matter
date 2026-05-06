# LDRH — load a half-word (16 bits) from memory, zero-extended into a 32-bit register

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
LDRH{<cond>}  <Rt>, [<Rn>{, #<imm>}]
LDRH{<cond>}  <Rt>, [<Rn>, <Rm>{, LSL #<n>}]
LDRH{<cond>}  <Rt>, [<Rn>, #<imm>]!
LDRH{<cond>}  <Rt>, [<Rn>], #<imm>
LDRH{<cond>}  <Rt>, <label>
```

Reads 16 bits and zero-extends. For sign-extension see [`LDRSH`](LDRSH.md).

**When you'd actually use this.** `LDRH` is the right load for any `uint16_t` source: 12-bit ADC samples that the peripheral places in the low half of a 16-bit FIFO word, packed audio buffers, UTF-16 code units, or 16-bit fields of a packet header. Zero-extension is what you want when the value is unsigned — the upper bits become 0, never sign-bits. The scaled-register form `[Rn, Rm, lsl #1]` is the canonical `uint16_t[]` indexer because each element is two bytes wide. Skipping `LDRH` and doing an `LDR` followed by `AND r, r, #0xFFFF` would cost an extra instruction and risk an unaligned-word fault at a half-word-aligned address that wasn't also word-aligned.

## Operands

| Field   | Type                 | Constraints                                                         |
|---------|----------------------|---------------------------------------------------------------------|
| `<Rt>`  | destination register | R0–R14.                                                             |
| `<Rn>`  | base register        | R0–R15.                                                             |
| `<Rm>`  | index register       | R0–R12.                                                             |
| `<imm>` | offset               | T1: imm5 ×2 (0–62). T2/T3: imm12/imm8.                              |

Address must be half-word aligned unless `CCR.UNALIGN_TRP = 0`.

## Operation (pseudocode)

```text
offset_addr = R[n] + offset;
address     = (index) ? offset_addr : R[n];
R[t]        = ZeroExtend(MemU[address, 2], 32);
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
| T1      | 16-bit | `LDRH <Rt>, [<Rn>, #<imm5*2>]` — low regs only.            |
| T2      | 16-bit | `LDRH <Rt>, [<Rn>, <Rm>]` — register offset, low regs only.|
| T2 (32) | 32-bit | `LDRH.W <Rt>, [<Rn>, #<imm12>]`.                           |
| T3 (32) | 32-bit | `LDRH.W <Rt>, [<Rn>, #±<imm8>]{!}` / post-indexed.         |
| T2 (32) | 32-bit | `LDRH.W <Rt>, [<Rn>, <Rm>{, LSL #0–3}]`.                   |
| T1 lit  | 32-bit | `LDRH.W <Rt>, <label>`.                                    |

## Exceptions / faults

- **UsageFault (UNALIGNED)** if `CCR.UNALIGN_TRP = 1` and address is odd.
- BusFault / MemManage on bus or MPU error.

## Example

### Example 1 — reading 16-bit ADC samples with scaled index

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ LDRH demo: reading 16-bit ADC samples from a buffer.
    ldr     r0, =adc_buffer
    ldrh    r1, [r0]                @ first sample, zero-extended
    ldrh    r2, [r0, #2]            @ next sample at +2
    movs    r3, #4
    ldrh    r4, [r0, r3, lsl #1]    @ scaled: r0 + r3*2 (5th sample)
    ldrh    r5, [r0], #2            @ post-index: load and advance pointer
loop:
    b       loop

    .align  2
adc_buffer:
    .hword  0x1111, 0x2222, 0x3333, 0x4444, 0x5555
```

**Walkthrough:**

1. `ldrh r1, [r0]` — reads 0x1111 into the low 16 bits of R1; upper 16 bits are zero.
2. `ldrh r2, [r0, #2]` — fetches the second sample.
3. `ldrh r4, [r0, r3, lsl #1]` — `lsl #1` scales the index by 2 because each element is 2 bytes — the canonical pattern for `uint16_t[]` lookup.
4. `ldrh r5, [r0], #2` — typical streaming read: take a sample, advance the pointer.

### Example 2 — polling a 16-bit peripheral interrupt-flags register

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ LDRH demo 2: poll a 16-bit peripheral interrupt-flags register (MMIO).
    ldr     r0, =0x4000A000         @ pretend timer base
poll:
    ldrh    r1, [r0, #0x10]         @ IF (interrupt-flag) register, 16-bit
    tst     r1, #(1 << 0)           @ test the OVF (overflow) bit
    beq     poll                    @ spin until set
    ldrh    r2, [r0, #0x14]         @ snapshot adjacent 16-bit register
loop:
    b       loop
```

**Walkthrough:**

1. `ldrh r1, [r0, #0x10]` — half-word read at *base + 0x10*; the address is half-word aligned (offset is even) and the upper 16 bits of R1 are zeroed automatically.
2. `tst` + `beq poll` — wait for the OVF flag to assert without modifying R1.
3. `ldrh r2, [r0, #0x14]` — read another adjacent 16-bit register from the same peripheral block, reusing the base pointer in R0.

## See also

- [LDRSH](LDRSH.md) — sign-extending half-word load (for `int16_t`).
- [LDRB](LDRB.md) / [LDRSB](LDRSB.md) — byte variants.
- [LDR](LDR.md) — full word load.
- [STRH](STRH.md) — symmetric half-word store.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.46–C2.4.48 — *LDRH (immediate/literal/register)*.
