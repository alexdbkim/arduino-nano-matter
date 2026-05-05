# LDAH — load-acquire of a half-word, zero-extended (ARMv8-M)

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base) — **new in ARMv8-M**
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
LDAH  <Rt>, [<Rn>]
```

Half-word sibling of [`LDA`](LDA.md). Reads 16 bits, zero-extends, and provides acquire ordering.

## Operands

| Field  | Type                 | Constraints                          |
|--------|----------------------|--------------------------------------|
| `<Rt>` | destination register | R0–R12, R14.                         |
| `<Rn>` | base register        | R0–R12, SP. No offset, no writeback. |

Address must be half-word aligned.

## Operation (pseudocode)

```text
address = R[n];
R[t] = ZeroExtend(MemA_with_acquire[address, 2], 32);
@ All later memory accesses in program order observe data from at least this load.
@ Flags unchanged.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form              |
|---------|--------|-------------------|
| T1      | 32-bit | `LDAH <Rt>, [<Rn>]` — only encoding. |

## Exceptions / faults

- **UsageFault (UNALIGNED)** if address is odd — always traps.
- BusFault / MemManage / SecureFault as for [`LDRH`](LDRH.md).

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Acquire-load a 16-bit sequence number then read paired data with ordering.
    ldr     r0, =seq
    ldr     r1, =data
poll:
    ldah    r2, [r0]                @ acquire half-word
    cmp     r2, #0
    beq     poll                    @ wait until non-zero
    ldr     r3, [r1]                @ ordered after LDAH
loop:
    b       loop

    .data
    .align  2
seq:
    .hword  0
    .align  2
data:
    .word   0
```

**Walkthrough:**

1. `ldah r2, [r0]` — acquire-load the 16-bit sequence number, zero-extended.
2. `cmp r2, #0 / beq poll` — spin until the producer bumps it.
3. `ldr r3, [r1]` — ordering is preserved: this load cannot be hoisted above the `LDAH`. This is the part that bites people: passing an unaligned address to `LDAH` always faults — `CCR.UNALIGN_TRP` does not help you here.

## See also

- [STLH](STLH.md) — symmetric release-store half-word.
- [LDRH](LDRH.md) — non-acquire half-word load.
- [LDA](LDA.md) / [LDAB](LDAB.md) — word and byte acquire loads.
- [LDAEXH](LDAEXH.md) — acquire + exclusive half-word load.
- [DMB](DMB.md) — full memory barrier.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.33 — *LDAH*.
