# STRD — store two registers as consecutive 32-bit words

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
STRD{<cond>}  <Rt>, <Rt2>, [<Rn>{, #±<imm>}]
STRD{<cond>}  <Rt>, <Rt2>, [<Rn>, #±<imm>]!     @ pre-indexed
STRD{<cond>}  <Rt>, <Rt2>, [<Rn>], #±<imm>      @ post-indexed
```

Writes `<Rt>` to `addr` and `<Rt2>` to `addr+4` in a single instruction.

## Operands

| Field    | Type            | Constraints                                                 |
|----------|-----------------|-------------------------------------------------------------|
| `<Rt>`   | first source    | R0–R12, R14.                                                |
| `<Rt2>`  | second source   | R0–R12, R14. May equal `<Rt>` (stores the same value twice).|
| `<Rn>`   | base register   | R0–R13. With writeback, must differ from `<Rt>` and `<Rt2>`.|
| `<imm>`  | offset          | imm8 ×4, range -1020..+1020, multiple of 4.                 |

No register-offset form. No PC-relative form. Address must be word-aligned.

## Operation (pseudocode)

```text
offset_addr = (add) ? R[n] + imm : R[n] - imm;
address     = (index) ? offset_addr : R[n];
MemA[address    , 4] = R[t];
MemA[address + 4, 4] = R[t2];
if wback then R[n] = offset_addr;
@ Flags unchanged.
```

`MemA` enforces alignment — unaligned `STRD` always faults.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form                                                                  |
|---------|--------|-----------------------------------------------------------------------|
| T1      | 32-bit | `STRD <Rt>, <Rt2>, [<Rn>{, #±<imm8*4>}]{!}` and post-indexed. Only encoding. |

## Exceptions / faults

- **UsageFault (UNALIGNED)** on any non-word-aligned address — always.
- BusFault / MemManage / SecureFault as appropriate.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ STRD demo: store a uint64_t and a pair of pointers to a struct.
    ldr     r0, =scratch
    movw    r2, #0x1111
    movt    r2, #0x1111             @ r2 = 0x11111111
    movw    r3, #0x2222
    movt    r3, #0x2222             @ r3 = 0x22222222
    strd    r2, r3, [r0]            @ scratch[0..1] = {r2, r3}
    strd    r2, r3, [r0, #8]        @ scratch[2..3] = {r2, r3}
    strd    r2, r3, [r0], #16       @ post-index: store, then bump r0 by 16
loop:
    b       loop

    .data
    .align  2
scratch:
    .space  64
```

**Walkthrough:**

1. `strd r2, r3, [r0]` — writes R2 at offset 0 and R3 at offset 4 with one instruction.
2. `strd r2, r3, [r0, #8]` — same pair, 8 bytes further along.
3. `strd r2, r3, [r0], #16` — post-indexed pair-store. This is the part that bites people: the writeback base must not equal either `<Rt>` or `<Rt2>`, and the address must be word-aligned (the `UNALIGN_TRP` bit doesn't save you here — `STRD` always traps on unaligned).

## See also

- [LDRD](LDRD.md) — symmetric paired load.
- [STR](STR.md) — single-word store.
- [STM](STM.md) — store-multiple, more flexible for >2 registers.
- [PUSH](PUSH.md) — store-multiple with SP writeback.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.174 — *STRD (immediate)*.
