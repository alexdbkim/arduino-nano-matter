# TBH — table branch halfword (compact forward jump table, 16-bit offsets)

## Class & availability

- **Class:** Branch
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
TBH   [<Rn>, <Rm>, LSL #1]
```

`TBH` is the wider sibling of `TBB`. It reads one *halfword* from `(<Rn> + (<Rm> << 1))`, multiplies that halfword by 2, and adds the result to the PC. The branch is forward-only with a maximum reach of `65535 × 2 = 131070` bytes (~128 KB) from the table — enough for switches whose case bodies are larger than 510 bytes total or where there are more than ~250 cases.

Each table entry is `(target − table_base) / 2` stored as `.short`. As with `TBB`, `<Rn> = PC` means "table follows the instruction"; that is the common form.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rn>` | base register | any of `r0`–`r15`. `SP` is not allowed. `PC` means "table follows this instruction". |
| `<Rm>` | index register | any of `r0`–`r14` (not `SP`, not `PC`). The `LSL #1` is mandatory and is part of the syntax — it accounts for the 2-byte entry size. |

## Operation (pseudocode)

```text
offset = ZeroExtend(MemU[Rn + (Rm << 1), halfword], 32)
PC     = PC + (offset << 1)
```

`TBH` does not write `LR` and does not affect APSR.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `TBH [<Rn>, <Rm>, LSL #1]` — only encoding |

## Exceptions / faults

- `MemManage` / `BusFault` if the halfword load faults (e.g. table placed in unmapped memory).
- `UsageFault (UNALIGNED)` if `CCR.UNALIGN_TRP = 1` and the table base is not halfword-aligned. Always `.align 1` (or better, `.align 2`) the table.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ TBH demo: same 4-way switch as TBB, but each case body is large (filler shown trimmed).
    movs    r0, #1
    cmp     r0, #3
    bhi     .Ldefault       @ TBH still won't bounds-check for you
    tbh     [pc, r0, lsl #1]
.Ltable:
    .short  (.Lcase0 - .Ltable) / 2
    .short  (.Lcase1 - .Ltable) / 2
    .short  (.Lcase2 - .Ltable) / 2
    .short  (.Lcase3 - .Ltable) / 2
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

1. `bhi .Ldefault` — index range check. `TBH` does not validate the index; an out-of-range value reads whatever follows the table.
2. `tbh [pc, r0, lsl #1]` — `r0` is shifted left 1 (halfword index → byte offset) and added to the table base; one halfword is loaded; that value is shifted left 1 and added to the PC.
3. `.short (.Lcase1 - .Ltable) / 2` — entry 1's halfword resolves to the (halved) byte distance from the table to `.Lcase1`. The runtime multiplication by 2 reverses the halving, so the maximum forward reach is 128 KB.
4. `movs r1, #20` — case 1 runs.
5. `.align 1` — keeps the case bodies halfword-aligned, required because the table value is multiplied by 2.

Use `TBH` over `TBB` when you have many cases or large case bodies; otherwise `TBB`'s 4-bytes-per-entry savings are usually worth it.

## See also

- [TBB](TBB.md) — narrower table (1 byte/entry, ≤510-byte reach).
- [B](B.md) — fallback when the switch needs backward branches.
- [BX](BX.md) — used with a `LDR Rx, =addr_table[i]`-style fully indirect dispatch.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.215 — *TBB, TBH*.
