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

## See also

- [STL](STL.md) — symmetric release-store.
- [LDR](LDR.md) — non-acquire plain load.
- [LDAB](LDAB.md) / [LDAH](LDAH.md) — byte and half-word acquire loads.
- [LDAEX](LDAEX.md) — acquire + exclusive load.
- [DMB](DMB.md) — full data memory barrier when finer ordering is needed.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.31 — *LDA*.
