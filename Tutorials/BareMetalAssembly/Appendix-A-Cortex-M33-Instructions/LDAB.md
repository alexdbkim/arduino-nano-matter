# LDAB — load-acquire of a byte, zero-extended (ARMv8-M)

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base) — **new in ARMv8-M**
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
LDAB  <Rt>, [<Rn>]
```

Byte sibling of [`LDA`](LDA.md). Reads one byte, zero-extends, and provides acquire semantics. New in ARMv8-M.

## Operands

| Field  | Type                 | Constraints                          |
|--------|----------------------|--------------------------------------|
| `<Rt>` | destination register | R0–R12, R14.                         |
| `<Rn>` | base register        | R0–R12, SP. No offset, no writeback. |

## Operation (pseudocode)

```text
address = R[n];
R[t] = ZeroExtend(MemA_with_acquire[address, 1], 32);
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
| T1      | 32-bit | `LDAB <Rt>, [<Rn>]` — only encoding. |

## Exceptions / faults

- BusFault / MemManage / SecureFault as for [`LDRB`](LDRB.md). No UNALIGNED — bytes are inherently aligned.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Acquire-poll a byte 'ready' flag, then read a multi-byte payload.
    ldr     r0, =flag
    ldr     r1, =payload
poll:
    ldab    r2, [r0]                @ acquire-load the byte flag
    cmp     r2, #0
    beq     poll
    ldr     r3, [r1]                @ guaranteed to observe the post-flag payload
loop:
    b       loop

    .data
    .align  2
flag:
    .byte   0
    .align  2
payload:
    .word   0
```

**Walkthrough:**

1. `ldab r2, [r0]` — atomically reads the flag byte with acquire ordering. Zero-extends to 32 bits.
2. `cmp / beq poll` — spin while the byte is still 0.
3. `ldr r3, [r1]` — the architecture forbids the CPU from speculating this load *before* the `LDAB` was observed by the rest of the system. This is the part that bites people: the same code with `LDRB` would need a `DMB` to be portable.

## See also

- [STLB](STLB.md) — symmetric release-store byte.
- [LDRB](LDRB.md) — non-acquire byte load.
- [LDA](LDA.md) / [LDAH](LDAH.md) — word and half-word acquire loads.
- [LDAEXB](LDAEXB.md) — acquire + exclusive byte load.
- [DMB](DMB.md) — full memory barrier alternative.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.32 — *LDAB*.
