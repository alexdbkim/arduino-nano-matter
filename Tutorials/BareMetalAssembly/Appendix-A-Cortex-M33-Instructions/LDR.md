# LDR — load a 32-bit word from memory into a register

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
LDR{<cond>}  <Rt>, [<Rn>{, #<imm>}]            @ immediate offset
LDR{<cond>}  <Rt>, [<Rn>, <Rm>{, LSL #<n>}]    @ register / scaled offset
LDR{<cond>}  <Rt>, [<Rn>, #<imm>]!             @ pre-indexed (writeback)
LDR{<cond>}  <Rt>, [<Rn>], #<imm>              @ post-indexed (writeback)
LDR{<cond>}  <Rt>, <label>                     @ PC-relative literal
LDR{<cond>}  <Rt>, =<expr>                     @ assembler literal-pool pseudo
```

`LDR` is the workhorse 32-bit load. Variants for narrower types: [`LDRB`](LDRB.md), [`LDRH`](LDRH.md), [`LDRSB`](LDRSB.md), [`LDRSH`](LDRSH.md), [`LDRD`](LDRD.md).

**When you'd actually use this.** Anytime a C compiler emits a 32-bit memory access for a `uint32_t`, a pointer, or a `volatile uint32_t *MMIO` peripheral register, you'll see `LDR`. The most common forms in EFR32MG24 firmware are `ldr r1, [r0, #0x1C]` to read a status register at *base + offset* (e.g. `USART0->STATUS`), and the assembler pseudo `ldr r0, =0x40000000` to materialise a peripheral base address — without it you'd burn two instructions (`MOVW`+`MOVT`) or a shift+OR sequence, whereas the literal-pool form is one instruction and works for *any* 32-bit constant. The post-indexed form `ldr r1, [r0], #4` is the inner loop of every word-aligned `memcpy`. Loading the PC produces an interworking branch — that's how function tail-calls through tables and `bx`-free dispatch work.

## Operands

| Field   | Type                 | Constraints                                                                         |
|---------|----------------------|-------------------------------------------------------------------------------------|
| `<Rt>`  | destination register | R0–R14. Writing PC produces an interworking branch (T1 PC-rel; T3 register form).   |
| `<Rn>`  | base register        | R0–R15. PC base = literal-pool form. SP allowed.                                    |
| `<Rm>`  | index register       | R0–R12 (T2 register form). Cannot be SP/PC.                                         |
| `<imm>` | offset               | T1 imm5 ×4 (0–124); T3/T4 imm12 (0–4095); negative ±255 in T4.                      |
| `LSL #<n>` | shift             | 0..3 — index register is left-shifted by 0/1/2/3.                                   |
| `<label>`| PC-rel target       | Word-aligned, within ±4 KB of `Align(PC,4)`.                                        |

## Operation (pseudocode)

```text
offset_addr = (add) ? R[n] + offset : R[n] - offset;
address     = (index) ? offset_addr : R[n];
data        = MemU[address, 4];                   @ unaligned-allowed by default
if wback then R[n] = offset_addr;
if t == 15 then
    LoadWritePC(data);                            @ interworking branch
else
    R[t] = data;
@ Flags unchanged.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Loads never touch flags.

## Encodings

| Variant | Width  | Form                                                               |
|---------|--------|--------------------------------------------------------------------|
| T1      | 16-bit | `LDR <Rt>, [<Rn>, #<imm5*4>]` — low regs only.                     |
| T2      | 16-bit | `LDR <Rt>, [SP, #<imm8*4>]` — SP-relative.                         |
| T3      | 16-bit | `LDR <Rt>, <label>` — PC-relative literal (low regs only, ±1 KB).  |
| T1 (32) | 32-bit | `LDR.W <Rt>, [<Rn>, #<imm12>]` — positive offset 0..4095.          |
| T4 (32) | 32-bit | `LDR.W <Rt>, [<Rn>, #±<imm8>]{!}` and post-indexed `[<Rn>], #±imm`.|
| T2 (32) | 32-bit | `LDR.W <Rt>, [<Rn>, <Rm>{, LSL #0–3}]` — register/scaled.          |
| T2 lit  | 32-bit | `LDR.W <Rt>, <label>` — PC-relative ±4095.                         |

## Exceptions / faults

- **BusFault** on bus error / region access denied.
- **MemManage** if MPU forbids the access.
- **UsageFault (UNALIGNED)** on unaligned access if `CCR.UNALIGN_TRP = 1`. Strongly-Ordered or Device memory always faults on unaligned word loads.
- **SecureFault** on cross-domain access without proper veneer (Security extension).

## Example

### Example 1 — every common addressing mode with a literal pool

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ LDR demo: every common addressing mode.
    ldr     r0, =0x40000000         @ literal pool — assembler picks MOVW/MOVT or pool
    ldr     r1, [r0]                @ immediate offset 0
    ldr     r2, [r0, #4]            @ immediate offset +4
    movs    r3, #2
    ldr     r4, [r0, r3, lsl #2]    @ scaled register offset (r0 + r3*4)
    ldr     r5, [r0, #8]!           @ pre-indexed: r0 += 8; r5 = *r0
    ldr     r6, [r0], #4            @ post-indexed: r6 = *r0; r0 += 4
    ldr     r7, my_const            @ PC-relative literal
loop:
    b       loop

    .align  2
my_const:
    .word   0xCAFEBABE
```

**Walkthrough:**

1. `ldr r0, =0x40000000` — assembler pseudo: emits `MOVW/MOVT` if it fits, else allocates a literal pool entry and loads from it.
2. `ldr r1, [r0]` / `ldr r2, [r0, #4]` — plain immediate offsets, the bread and butter.
3. `ldr r4, [r0, r3, lsl #2]` — index a `uint32_t` array: `r3` is the element index, `lsl #2` scales by 4 (word size).
4. `ldr r5, [r0, #8]!` — *pre-indexed*: base updates **before** the load. Equivalent to `r0 += 8; r5 = *r0;`.
5. `ldr r6, [r0], #4` — *post-indexed*: load first, then bump. Idiomatic for streaming reads.
6. `ldr r7, my_const` — PC-relative literal pool. The label must be word-aligned and within ±4 KB.

### Example 2 — polling a peripheral status register (MMIO)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ LDR demo 2: poll a peripheral status register at base+offset.
    ldr     r0, =0x40010000         @ pretend USART base
poll:
    ldr     r1, [r0, #0x1C]         @ read STATUS register (offset 0x1C)
    tst     r1, #(1 << 7)           @ test TX-buffer-empty flag
    beq     poll                    @ spin until ready
    ldr     r2, [r0, #0x00]         @ snapshot CTRL register using same base
loop:
    b       loop
```

**Walkthrough:**

1. `ldr r0, =0x40010000` — assembler pseudo: materialises the peripheral base address, typically as `MOVW`+`MOVT` (or a literal-pool fetch on encodings where that's smaller).
2. `ldr r1, [r0, #0x1C]` — single MMIO read of the STATUS register; `[Rn, #imm]` with a constant offset is the canonical pattern for register accesses inside a peripheral block.
3. `tst` + `beq poll` — busy-wait for the flag bit; doesn't change R1.
4. `ldr r2, [r0, #0x00]` — read CTRL using the *same* base register — exactly why you spend one instruction loading the base and then reuse it for every register in the block.

## See also

- [STR](STR.md) — the symmetric store.
- [LDRB](LDRB.md) / [LDRH](LDRH.md) / [LDRSB](LDRSB.md) / [LDRSH](LDRSH.md) — narrower loads.
- [LDRD](LDRD.md) — load two words at once.
- [LDM](LDM.md) — load multiple words sequentially.
- [LDA](LDA.md) — acquire-semantic word load (v8-M).
- [LDREX](LDREX.md) — exclusive monitor word load for atomics.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.51–C2.4.55 — *LDR (immediate)*, *LDR (literal)*, *LDR (register)*.
