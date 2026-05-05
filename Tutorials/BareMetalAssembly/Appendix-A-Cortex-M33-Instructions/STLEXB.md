# STLEXB — store-release-exclusive of a byte (ARMv8-M)

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base) — **new in ARMv8-M**
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
STLEXB  <Rd>, <Rt>, [<Rn>]
```

Byte version of [`STLEX`](STLEX.md). Pairs with [`LDAEXB`](LDAEXB.md).

## Operands

| Field  | Type             | Constraints                                            |
|--------|------------------|--------------------------------------------------------|
| `<Rd>` | success register | R0–R12, R14. Must differ from `<Rt>` and `<Rn>`.       |
| `<Rt>` | source register  | R0–R12, R14.                                           |
| `<Rn>` | base register    | R0–R12, SP. No offset.                                 |

## Operation (pseudocode)

```text
address = R[n];
if ExclusiveMonitorsPass(address, 1) then
    MemA_with_release[address, 1] = R[t]<7:0>;
    R[d] = 0;
else
    R[d] = 1;
ClearExclusiveMonitors();
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form                                |
|---------|--------|-------------------------------------|
| T1      | 32-bit | `STLEXB <Rd>, <Rt>, [<Rn>]` — only encoding. |

## Exceptions / faults

- BusFault / MemManage / SecureFault as for [`STRB`](STRB.md). No UNALIGNED.

## Example — paired with LDAEXB

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Byte-wide test-and-set with proper ordering.
    ldr     r0, =lock
    movs    r3, #1
spin:
    ldaexb  r1, [r0]
    cmp     r1, #0
    bne     spin
    stlexb  r2, r3, [r0]
    cmp     r2, #0
    bne     spin
    @ critical section ...
    movs    r3, #0
    stlb    r3, [r0]                @ release
loop:
    b       loop

    .data
lock:
    .byte   0
    .align  2
```

**Walkthrough:**

1. `ldaexb r1, [r0]` — acquire-load lock byte, arm monitor.
2. Spin if held.
3. `stlexb r2, r3, [r0]` — atomic release-store of "1". Sets the lock and gives release ordering wrt anything earlier (none here, but the *next* thread's writes inside the critical section will be ordered by this acquire/release pair).
4. The critical section follows; it's released with a plain `STLB`.
5. This is the part that bites people: the lock byte is a `.byte` followed by `.align 2` so the next data is word-aligned — the lock itself doesn't need alignment for `STLEXB`.

## See also

- [LDAEXB](LDAEXB.md) — required partner.
- [STREXB](STREXB.md) — exclusive byte store without release.
- [STLEX](STLEX.md) / [STLEXH](STLEXH.md) — word and half-word variants.
- [STLB](STLB.md) — non-exclusive release byte store.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.159 — *STLEXB*.
