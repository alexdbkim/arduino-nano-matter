# STLB — store-release of a byte (ARMv8-M)

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base) — **new in ARMv8-M**
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
STLB  <Rt>, [<Rn>]
```

Byte release-store. Symmetric to [`LDAB`](LDAB.md). Stores `R[t]<7:0>` with release ordering.

## Operands

| Field  | Type            | Constraints                          |
|--------|-----------------|--------------------------------------|
| `<Rt>` | source register | R0–R12, R14.                         |
| `<Rn>` | base register   | R0–R12, SP. No offset, no writeback. |

## Operation (pseudocode)

```text
address = R[n];
@ All earlier memory accesses in program order are observed by others before this store.
MemA_with_release[address, 1] = R[t]<7:0>;
@ Flags unchanged.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form               |
|---------|--------|--------------------|
| T1      | 32-bit | `STLB <Rt>, [<Rn>]` — only encoding. |

## Exceptions / faults

- BusFault / MemManage / SecureFault as for [`STRB`](STRB.md). No UNALIGNED.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Release a byte spinlock. Earlier critical-section writes are observed first.
    ldr     r0, =lock
    ldr     r1, =shared
    movs    r2, #99
    str     r2, [r1]                @ critical-section write
    movs    r3, #0
    stlb    r3, [r0]                @ release: clear the lock byte
loop:
    b       loop

    .data
    .align  2
shared:
    .word   0
lock:
    .byte   1
    .align  2
```

**Walkthrough:**

1. `str r2, [r1]` — work inside a held critical section.
2. `stlb r3, [r0]` — clear the lock byte using a release-store. Any other thread that does `LDAB` and sees the cleared byte is architecturally guaranteed to also see the `[r1]` write that preceded it.
3. This is the part that bites people: a plain `STRB` here would let later observers see the cleared lock *before* the protected data was committed — a textbook lock-release reordering bug.

## See also

- [LDAB](LDAB.md) — symmetric acquire byte load.
- [STRB](STRB.md) — non-release byte store.
- [STL](STL.md) / [STLH](STLH.md) — word and half-word release-stores.
- [STLEXB](STLEXB.md) — release + exclusive byte store.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.163 — *STLB*.
