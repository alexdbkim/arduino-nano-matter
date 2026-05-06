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

**When you'd actually use this** an 8-bit *ready* or *state* flag is packed into a struct beside the data it gates — `LDAB` reads the byte and fences subsequent loads in one instruction, no separate `DMB` needed. Compilers emit it for C11 acquire-loads of `_Atomic uint8_t`. Common in producer/consumer ring buffers between an ISR and a worker loop, where each slot has a 1-byte *valid* marker. Without `LDAB` you'd need `LDRB` + `DMB ISHLD`, which is more code and locks down ordering more aggressively.

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

### Example 1 — Byte ready-flag acquire-poll

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

### Example 2 — Decode a state byte after acquire

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Read a state-machine byte; only after acquire-load is it safe to read params.
    ldr     r0, =state
    ldr     r1, =param_block
    ldab    r2, [r0]                @ acquire-load the state byte
    cmp     r2, #2                  @ STATE_RUN == 2?
    bne     idle
    ldr     r3, [r1, #0]            @ params associated with STATE_RUN
idle:
loop:
    b       loop

    .data
    .align  2
param_block:
    .word   0
state:
    .byte   0
    .align  2
```

**Walkthrough:**

1. `LDAB r2, [r0]` acquire-loads the state byte and zero-extends it.
2. Branching on the value is plain register work; the dependent `LDR` of the parameter block cannot be hoisted above the `LDAB`.
3. A producer that writes `param_block` first and then `STLB`s the state byte is therefore guaranteed visible to this reader as a consistent snapshot.

## See also

- [STLB](STLB.md) — symmetric release-store byte.
- [LDRB](LDRB.md) — non-acquire byte load.
- [LDA](LDA.md) / [LDAH](LDAH.md) — word and half-word acquire loads.
- [LDAEXB](LDAEXB.md) — acquire + exclusive byte load.
- [DMB](DMB.md) — full memory barrier alternative.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.32 — *LDAB*.
