# LDA — load-acquire of a 32-bit word (release/acquire ordering)

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base) — **new in ARMv8-M**
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
LDA  <Rt>, [<Rn>]
```

Like [`LDR`](LDR.md), but the access has *acquire* memory-ordering semantics: any subsequent memory access in program order is observed *after* this load by other observers. New in ARMv8-M — neither ARMv7-M nor ARMv6-M had it.

**When you'd actually use this** a foreground task waits on a *data-ready* flag that an ISR (or another core) sets after filling a ring-buffer slot — `LDA` of the flag fences subsequent payload reads so they cannot be hoisted above the flag check. C11 compilers emit this for `atomic_load_explicit(x, memory_order_acquire)`. The single-sided fence is cheaper than a full `DMB ISH` and self-documenting in disassembly. On a single-issue M33 a plain `LDR` *appears* to work, but the moment the code is ported to a Cortex-A or future M-profile part with reordering it silently breaks.

## Operands

| Field  | Type                 | Constraints                          |
|--------|----------------------|--------------------------------------|
| `<Rt>` | destination register | R0–R12, R14.                         |
| `<Rn>` | base register        | R0–R12, SP. No offset, no writeback. |

Address must be word-aligned.

## Operation (pseudocode)

```text
address = R[n];
R[t] = MemA_with_acquire[address, 4];
@ All later memory accesses in program order observe data from at least this load.
@ Flags unchanged.
```

Acquire semantics give you a one-sided "fence" — cheaper than a full [`DMB`](DMB.md) on systems where it matters. On a single-issue M33 the *practical* difference vs. plain `LDR` is small, but the semantic guarantee is what makes lock-free code portable.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form              |
|---------|--------|-------------------|
| T1      | 32-bit | `LDA <Rt>, [<Rn>]` — only encoding. |

## Exceptions / faults

- **UsageFault (UNALIGNED)** on non-word-aligned address — always.
- BusFault / MemManage / SecureFault as for [`LDR`](LDR.md).

## Example

### Example 1 — Acquire-poll a ready flag

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Producer/consumer "ready flag" pattern: reader uses LDA to acquire.
    ldr     r0, =flag
    ldr     r1, =payload
poll:
    lda     r2, [r0]                @ acquire-load the flag
    cmp     r2, #0
    beq     poll
    ldr     r3, [r1]                @ this load is guaranteed observed AFTER the LDA
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

1. `lda r2, [r0]` — reads the flag with acquire semantics.
2. `cmp / beq poll` — spin until the producer publishes a non-zero flag.
3. `ldr r3, [r1]` — once we see the flag, the architecturally guaranteed ordering means this payload load cannot be reordered *before* the `LDA`. Without `LDA` (i.e. plain `LDR` for the flag), you'd need a [`DMB`](DMB.md) between the flag-check and the payload-read on a multi-issue or multi-core system. This is the part that bites people: M33 in this SoC is single-core, so a plain `LDR` *appears* to behave the same — your code becomes non-portable to Cortex-A or future M-profile parts that exploit reordering.

### Example 2 — Consume a published linked node

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Reader pops a node pointer published by a producer with STL.
    ldr     r0, =head_ptr
    lda     r1, [r0]                @ acquire the head pointer
    cbz     r1, empty               @ null → list empty
    ldr     r2, [r1, #0]            @ node->value — load is ordered after LDA
    ldr     r3, [r1, #4]            @ node->next  — same
empty:
loop:
    b       loop

    .data
    .align  2
head_ptr:
    .word   0
```

**Walkthrough:**

1. `LDA r1, [r0]` acquire-loads the head pointer published by the producer.
2. If non-null, the two `LDR`s read the node fields. The architecture forbids the CPU from speculatively issuing those loads *before* the `LDA` is observed — so the producer's writes to `node->value`/`node->next` (sequenced before its `STL`) are guaranteed visible.
3. Replace `LDA` with `LDR` and you have a classic *consume-bug*: the reader could see a non-null pointer with stale node fields.

## See also

- [STL](STL.md) — symmetric release-store.
- [LDR](LDR.md) — non-acquire plain load.
- [LDAB](LDAB.md) / [LDAH](LDAH.md) — byte and half-word acquire loads.
- [LDAEX](LDAEX.md) — acquire + exclusive load.
- [DMB](DMB.md) — full data memory barrier when finer ordering is needed.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.31 — *LDA*.
