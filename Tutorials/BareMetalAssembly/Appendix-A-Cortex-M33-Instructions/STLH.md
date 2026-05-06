# STLH — store-release of a half-word (ARMv8-M)

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base) — **new in ARMv8-M**
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
STLH  <Rt>, [<Rn>]
```

Half-word release-store. Symmetric to [`LDAH`](LDAH.md). Stores `R[t]<15:0>` with release ordering.

**When you'd actually use this** a producer publishes via a 16-bit field — most often a sequence number or version counter that gates a larger payload. `STLH` writes the half-word with release semantics so that a reader doing `LDAH` of the version is guaranteed to see all prior data writes. The 16-bit width is preferred when the version lives in a small RAM block or shares a cache line with its data. Without `STLH`, the publish-before-data reordering hazard is identical to the 32-bit case — except now you'd need `DMB ISHST` plus `STRH`.

## Operands

| Field  | Type            | Constraints                          |
|--------|-----------------|--------------------------------------|
| `<Rt>` | source register | R0–R12, R14.                         |
| `<Rn>` | base register   | R0–R12, SP. No offset, no writeback. |

Address must be half-word aligned.

## Operation (pseudocode)

```text
address = R[n];
@ All earlier memory accesses in program order are observed by others before this store.
MemA_with_release[address, 2] = R[t]<15:0>;
@ Flags unchanged.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form               |
|---------|--------|--------------------|
| T1      | 32-bit | `STLH <Rt>, [<Rn>]` — only encoding. |

## Exceptions / faults

- **UsageFault (UNALIGNED)** if address is odd — always.
- BusFault / MemManage / SecureFault as for [`STRH`](STRH.md).

## Example

### Example 1 — Publish a 16-bit sequence

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Publish a 16-bit sequence number after writing the data slot.
    ldr     r0, =seq
    ldr     r1, =data
    movw    r2, #0xBEEF
    str     r2, [r1]                @ data first
    movw    r3, #0x0001
    stlh    r3, [r0]                @ then publish seq with release ordering
loop:
    b       loop

    .data
    .align  2
data:
    .word   0
    .align  2
seq:
    .hword  0
```

**Walkthrough:**

1. `str r2, [r1]` — write the protected data with a plain store.
2. `stlh r3, [r0]` — bump the 16-bit sequence number using release. A reader doing `LDAH` and seeing the new seq is guaranteed to also see the data write.
3. This is the part that bites people: `STLH` traps on odd addresses regardless of `CCR.UNALIGN_TRP` — the trick of "set UNALIGN_TRP=0 to allow misaligned" only applies to plain `STRH`, not the release/acquire family.

### Example 2 — Release a 16-bit error code

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Worker fills an error context, then publishes a 16-bit error code.
    ldr     r0, =err_code
    ldr     r1, =err_ctx
    movw    r2, #0xDEAD
    str     r2, [r1, #0]            @ context word
    movw    r3, #0x0042             @ ERR_FAULT = 0x42
    stlh    r3, [r0]                @ release-publish error code
loop:
    b       loop

    .data
    .align  2
err_ctx:
    .word   0
err_code:
    .hword  0
```

**Walkthrough:**

1. `STR` populates the error context — readers cannot interpret it yet because `err_code` is still 0.
2. `STLH` publishes the 16-bit error code with release ordering. A handler doing `LDAH err_code` and seeing non-zero is guaranteed to also see the context write.
3. `STLH` traps on odd addresses regardless of `CCR.UNALIGN_TRP` — `.align 2` ensures the half-word is at an even address.

## See also

- [LDAH](LDAH.md) — symmetric acquire half-word load.
- [STRH](STRH.md) — non-release half-word store.
- [STL](STL.md) / [STLB](STLB.md) — word and byte release-stores.
- [STLEXH](STLEXH.md) — release + exclusive half-word store.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.164 — *STLH*.
