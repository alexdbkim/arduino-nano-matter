# TBB — table branch byte (compact forward jump table, 8-bit offsets)

## Class & availability

- **Class:** Branch
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
TBB   [<Rn>, <Rm>]
```

`TBB` implements a switch/case jump table compactly. It reads one byte from `(<Rn> + <Rm>)`, multiplies that byte by 2, and adds the result to the PC to form the new PC. The branch is therefore **forward-only** and has a maximum reach of `255 × 2 = 510` bytes from the table.

The byte you store in the table is `(target − table_base) / 2`. The assembler computes that for you with the `(target - table_base)/2` expression, but most tools provide the `.byte (target - table_base)/2` idiom directly.

When `<Rn>` is `PC`, the table is assumed to start at the instruction immediately after the `TBB` — that's the form you'll see almost everywhere.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rn>` | base register | any of `r0`–`r15`. `SP` is not allowed. `PC` means "table follows this instruction". |
| `<Rm>` | index register | any of `r0`–`r14` (not `SP`, not `PC`). Must hold an unsigned byte index. |

## Operation (pseudocode)

```text
offset = ZeroExtend(MemU[Rn + Rm, byte], 32)
PC     = PC + (offset << 1)
```

`PC` reads as the address of the instruction after `TBB` plus 4 (Thumb pipeline rule). `TBB` does not write `LR` and does not affect APSR.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `TBB [<Rn>, <Rm>]` — only encoding |

## Exceptions / faults

- `MemManage` / `BusFault` if the table load faults.
- `UsageFault (INVSTATE)` if the computed PC ever lands on a non-Thumb address — impossible with assembler-generated tables, but possible if you hand-craft a malformed `.byte` value.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ TBB demo: 4-way switch on r0 (0..3), result accumulated in r1.
    movs    r1, #0
    movs    r0, #2          @ pick case 2
    cmp     r0, #3
    bhi     .Ldefault       @ bounds-check the index — TBB will not do it for you
    tbb     [pc, r0]
.Ltable:
    .byte   (.Lcase0 - .Ltable) / 2
    .byte   (.Lcase1 - .Ltable) / 2
    .byte   (.Lcase2 - .Ltable) / 2
    .byte   (.Lcase3 - .Ltable) / 2
    .align  1
.Lcase0:
    movs    r1, #10
    b       .Ldone
.Lcase1:
    movs    r1, #20
    b       .Ldone
.Lcase2:
    movs    r1, #30
    b       .Ldone
.Lcase3:
    movs    r1, #40
    b       .Ldone
.Ldefault:
    movs    r1, #0xFF
.Ldone:
loop:
    b       loop
```

**Walkthrough:**

1. `bhi .Ldefault` — explicit upper-bound check. `TBB` performs no range check; an out-of-range index reads garbage from whatever follows the table and jumps to wherever that decodes to. **Always bounds-check first.**
2. `tbb [pc, r0]` — fetch byte at `&.Ltable + r0` (the assembler positions the table immediately after the instruction), shift left 1, add to PC, jump.
3. `.byte (.Lcase2 - .Ltable) / 2` — entry 2 says "from the table base, the case-2 code is N halfwords ahead".
4. `movs r1, #30` — case 2 runs and produces the expected result.
5. `.align 1` — keeps the case bodies halfword-aligned, which matters because `TBB` multiplies the table byte by 2.

The total table is 4 bytes long instead of 16 bytes for an `LDR PC, [PC, Rn, LSL #2]`-style jump table. That's the whole point.

## See also

- [TBH](TBH.md) — same idea with halfword entries for ranges up to 128 KB.
- [B](B.md) — fallback for switches that need backward reach or large per-case ranges.
- [BX](BX.md) — register-indirect alternative when the targets are arbitrary function pointers.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.215 — *TBB, TBH*.
