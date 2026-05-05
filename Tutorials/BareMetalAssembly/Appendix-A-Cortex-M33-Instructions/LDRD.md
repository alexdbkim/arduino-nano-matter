# LDRD — load two consecutive 32-bit words into a register pair

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
LDRD{<cond>}  <Rt>, <Rt2>, [<Rn>{, #±<imm>}]
LDRD{<cond>}  <Rt>, <Rt2>, [<Rn>, #±<imm>]!     @ pre-indexed (writeback)
LDRD{<cond>}  <Rt>, <Rt2>, [<Rn>], #±<imm>      @ post-indexed (writeback)
LDRD{<cond>}  <Rt>, <Rt2>, <label>              @ PC-relative
```

`<Rt>` ← `MemU[addr, 4]`, `<Rt2>` ← `MemU[addr+4, 4]`. Useful for 64-bit loads, pairs of pointers, or context save/restore.

## Operands

| Field    | Type                | Constraints                                                              |
|----------|---------------------|--------------------------------------------------------------------------|
| `<Rt>`   | first destination   | R0–R12, R14. Must differ from `<Rt2>`.                                   |
| `<Rt2>`  | second destination  | R0–R12, R14. Must differ from `<Rt>` and from `<Rn>` if writeback.       |
| `<Rn>`   | base register       | R0–R15. PC = literal form.                                               |
| `<imm>`  | offset              | imm8 ×4, range -1020..+1020, multiple of 4.                              |

The address must be word-aligned. There is **no** register-offset form — only immediate or literal.

## Operation (pseudocode)

```text
offset_addr = (add) ? R[n] + imm : R[n] - imm;
address     = (index) ? offset_addr : R[n];
R[t]        = MemA[address    , 4];
R[t2]       = MemA[address + 4, 4];
if wback then R[n] = offset_addr;
@ Flags unchanged.
```

`MemA` enforces alignment; an unaligned `LDRD` always faults regardless of `CCR.UNALIGN_TRP`.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form                                                                  |
|---------|--------|-----------------------------------------------------------------------|
| T1      | 32-bit | `LDRD <Rt>, <Rt2>, [<Rn>{, #±<imm8*4>}]{!}` and post-indexed. Only encoding. |

No 16-bit form. Always emits a 32-bit instruction.

## Exceptions / faults

- **UsageFault (UNALIGNED)** on any non-word-aligned address — always, not gated by `CCR.UNALIGN_TRP`.
- BusFault / MemManage on bus or MPU error.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ LDRD demo: load a struct { uint32_t lo; uint32_t hi; } as a 64-bit pair.
    ldr     r0, =u64_value
    ldrd    r2, r3, [r0]            @ r2 = lo, r3 = hi
    ldrd    r4, r5, [r0, #8]        @ second pair at +8
    ldrd    r6, r7, [r0], #16       @ post-index: load and advance r0 by 16
loop:
    b       loop

    .align  2
u64_value:
    .word   0x11111111, 0x22222222
    .word   0x33333333, 0x44444444
    .word   0x55555555, 0x66666666
```

**Walkthrough:**

1. `ldrd r2, r3, [r0]` — single instruction loads two consecutive words; on most M-class implementations this is two bus transfers but a single decoded op.
2. `ldrd r4, r5, [r0, #8]` — fetches the second 8-byte pair without disturbing R0.
3. `ldrd r6, r7, [r0], #16` — post-indexed: handy for streaming through a buffer of paired words. This is the part that bites people: `<Rt>`, `<Rt2>`, and `<Rn>` (with writeback) must all be distinct registers, otherwise the encoding is UNPREDICTABLE.

## See also

- [STRD](STRD.md) — symmetric paired store.
- [LDR](LDR.md) — single-word load.
- [LDM](LDM.md) — load-multiple, more flexible for >2 registers.
- [POP](POP.md) — load-multiple with SP writeback.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.44–C2.4.45 — *LDRD (immediate/literal)*.
