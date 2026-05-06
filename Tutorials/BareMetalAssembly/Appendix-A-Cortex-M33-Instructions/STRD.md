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

**When you'd actually use this**: storing a 64-bit timestamp/cycle-counter pair (low + high halves) into a log slot, snapshotting two adjacent `uint32_t` struct fields like `{head, tail}` of a queue, or emitting two pointers (`prev`, `next`) of a doubly-linked-list node in one go. Because both words land in a single instruction it's also handy for code-size — and it's the natural store for AAPCS 64-bit return values held in `{r0, r1}`. Without `STRD` you'd issue two separate `STR`s, which is no faster but takes twice the encoded bytes; the trade-off is `STRD` is strictly word-aligned (the `UNALIGN_TRP` bit cannot rescue you) and the writeback base must not collide with `<Rt>`/`<Rt2>`.

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

### Example 1 — Pair-stores with all addressing modes

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

### Example 2 — Log a 64-bit timestamp into a slot

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Capture DWT->CYCCNT (32-bit) plus a software hi-counter into a log entry.
    ldr     r0, =0xE0001004     @ DWT->CYCCNT
    ldr     r1, =hi_counter     @ &hi_counter (uint32_t)
    ldr     r2, [r0]            @ lo = CYCCNT
    ldr     r3, [r1]            @ hi
    ldr     r0, =log_slot
    strd    r2, r3, [r0]        @ slot = {lo, hi} as a uint64_t
loop:
    b       loop

    .data
    .align  2
hi_counter: .word 0
log_slot:   .space 8
```

**Walkthrough:**

1. The two halves of the 64-bit timestamp live in `r2` (low) and `r3` (high); `STRD` writes them as one operation to consecutive words.
2. `log_slot` is `.align 2`, i.e. word-aligned — required, since `STRD` traps unconditionally on unaligned addresses.
3. Two separate `STR` instructions would also work but cost an extra encoded halfword and could be split by an interrupt between the two writes; the single `STRD` is one bus burst.

## See also

- [LDRD](LDRD.md) — symmetric paired load.
- [STR](STR.md) — single-word store.
- [STM](STM.md) — store-multiple, more flexible for >2 registers.
- [PUSH](PUSH.md) — store-multiple with SP writeback.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.174 — *STRD (immediate)*.
