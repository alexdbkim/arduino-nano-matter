# STL — store-release of a 32-bit word (ARMv8-M)

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base) — **new in ARMv8-M**
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
STL  <Rt>, [<Rn>]
```

Symmetric to [`LDA`](LDA.md): a plain word store but with *release* memory-ordering semantics. Any earlier memory access in program order is observed by other agents *before* this store. New in ARMv8-M.

## Operands

| Field  | Type            | Constraints                          |
|--------|-----------------|--------------------------------------|
| `<Rt>` | source register | R0–R12, R14.                         |
| `<Rn>` | base register   | R0–R12, SP. No offset, no writeback. |

Address must be word-aligned.

## Operation (pseudocode)

```text
address = R[n];
@ All earlier memory accesses in program order are observed by others before this store.
MemA_with_release[address, 4] = R[t];
@ Flags unchanged.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form              |
|---------|--------|-------------------|
| T1      | 32-bit | `STL <Rt>, [<Rn>]` — only encoding. |

## Exceptions / faults

- **UsageFault (UNALIGNED)** on non-word-aligned address — always.
- BusFault / MemManage / SecureFault as for [`STR`](STR.md).

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Producer side: write payload first, then publish flag with release-store.
    ldr     r0, =flag
    ldr     r1, =payload
    movw    r2, #0xFACE
    movt    r2, #0xCAFE             @ r2 = 0xCAFEFACE
    str     r2, [r1]                @ stash payload (plain store)
    movs    r3, #1
    stl     r3, [r0]                @ release-store the flag
loop:
    b       loop

    .data
    .align  2
flag:
    .word   0
payload:
    .word   0
```

**Walkthrough:**

1. `str r2, [r1]` — write the payload data with a plain store.
2. `stl r3, [r0]` — publish the "ready" flag with release semantics. The architecture guarantees the payload write is visible to any other observer that sees the new flag value. Pairs with a reader using [`LDA`](LDA.md).
3. This is the part that bites people: on this single-core M33 the timing happens to work even with a plain `STR` for the flag, but on any architecture where the CPU may reorder stores you'd silently corrupt the protocol. Always use `STL` (or a `DMB ISHST` followed by `STR`) to publish.

## See also

- [LDA](LDA.md) — symmetric acquire-load.
- [STR](STR.md) — non-release plain store.
- [STLB](STLB.md) / [STLH](STLH.md) — byte and half-word release-stores.
- [STLEX](STLEX.md) — release-store + exclusive monitor (pairs with LDAEX).
- [DMB](DMB.md) — explicit memory barrier alternative.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.162 — *STL*.
