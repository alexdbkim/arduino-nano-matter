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

**When you'd actually use this** the producer side of an 8-bit *ready* flag or a byte-sized lock release where prior critical-section writes must be visible to other agents *before* the byte change. Common when the publish flag is byte-sized to share a cache line with its data. `STLB` is the C11 release-store of `_Atomic uint8_t`. Without it, a plain `STRB` followed by `LDAB` in the reader doesn't enforce ordering — you'd need a `DMB ISHST` between data writes and the flag store.

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

### Example 1 — Release-clear a byte spinlock

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

### Example 2 — Publish a byte command code

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Producer writes a payload, then publishes a 1-byte command code.
    ldr     r0, =cmd
    ldr     r1, =payload
    movw    r2, #0xBEEF
    str     r2, [r1]                @ payload first
    movs    r3, #5                  @ CMD_RUN = 5
    stlb    r3, [r0]                @ release-publish the command byte
loop:
    b       loop

    .data
    .align  2
payload:
    .word   0
cmd:
    .byte   0
    .align  2
```

**Walkthrough:**

1. `STR` writes the payload word with no ordering constraint.
2. `STLB` writes the 1-byte command code with release ordering — any reader that does `LDAB cmd` and sees `5` is guaranteed to also see the payload write.
3. Plain `STRB` here would compile and look identical on M33 in single-core scenarios, but is wrong on any system that may reorder stores.

## See also

- [LDAB](LDAB.md) — symmetric acquire byte load.
- [STRB](STRB.md) — non-release byte store.
- [STL](STL.md) / [STLH](STLH.md) — word and half-word release-stores.
- [STLEXB](STLEXB.md) — release + exclusive byte store.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.163 — *STLB*.
