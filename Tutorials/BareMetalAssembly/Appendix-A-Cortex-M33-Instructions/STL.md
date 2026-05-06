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

**When you'd actually use this** the producer side of a single-producer / single-consumer ring buffer or mailbox: write the data slot first, then `STL` of a *ready* flag (or the new head pointer). Release ordering means a reader that sees the published flag with `LDA` is *guaranteed* to also see the prior data writes. Compilers emit this for `atomic_store_explicit(x, memory_order_release)`. Without `STL` you have to insert a `DMB ISHST` between the data store and the flag store; on weakly-ordered cores skipping it is a textbook publish-bug.

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

### Example 1 — Publish a ready-flag

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

### Example 2 — Publish a linked-list node

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Producer: write a node's fields, then publish the head pointer with STL.
    ldr     r0, =head_ptr
    ldr     r1, =node
    movw    r2, #42
    str     r2, [r1, #0]            @ node->value
    movs    r3, #0
    str     r3, [r1, #4]            @ node->next = NULL
    stl     r1, [r0]                @ publish: readers see node fully initialised
loop:
    b       loop

    .data
    .align  2
head_ptr:
    .word   0
node:
    .word   0
    .word   0
```

**Walkthrough:**

1. Two plain `STR`s populate the node fields. No reader can observe the node yet because `head_ptr` is still null.
2. `STL r1, [r0]` writes the pointer to `head_ptr` with release ordering. The architecture guarantees that any reader doing `LDA` on `head_ptr` and seeing this pointer also sees the field writes that precede it in program order.
3. Replace `STL` with plain `STR` and on a reordering core a reader could observe a non-null `head_ptr` with garbage `value`/`next` — the canonical *publish-before-init* bug.

## See also

- [LDA](LDA.md) — symmetric acquire-load.
- [STR](STR.md) — non-release plain store.
- [STLB](STLB.md) / [STLH](STLH.md) — byte and half-word release-stores.
- [STLEX](STLEX.md) — release-store + exclusive monitor (pairs with LDAEX).
- [DMB](DMB.md) — explicit memory barrier alternative.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.162 — *STL*.
