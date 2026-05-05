# LDAEXB — load-acquire-exclusive of a byte (ARMv8-M)

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base) — **new in ARMv8-M**
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
LDAEXB  <Rt>, [<Rn>]
```

Byte version of [`LDAEX`](LDAEX.md). Acquire ordering plus exclusive-monitor arming, byte-sized. Pairs with [`STLEXB`](STLEXB.md).

## Operands

| Field  | Type                 | Constraints                          |
|--------|----------------------|--------------------------------------|
| `<Rt>` | destination register | R0–R12, R14.                         |
| `<Rn>` | base register        | R0–R12, SP. No offset, no writeback. |

## Operation (pseudocode)

```text
address = R[n];
SetExclusiveMonitors(address, 1);
R[t] = ZeroExtend(MemA_with_acquire[address, 1], 32);
@ Flags unchanged.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form                |
|---------|--------|---------------------|
| T1      | 32-bit | `LDAEXB <Rt>, [<Rn>]` — only encoding. |

## Exceptions / faults

- BusFault / MemManage / SecureFault as for [`LDRB`](LDRB.md). No UNALIGNED.

## Example — paired with STLEXB

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Test-and-set spinlock with proper ordering on a byte.
    ldr     r0, =lock
    movs    r3, #1
acquire:
    ldaexb  r1, [r0]
    cmp     r1, #0
    bne     acquire
    stlexb  r2, r3, [r0]
    cmp     r2, #0
    bne     acquire
    @ critical section ...
    movs    r3, #0
    stlb    r3, [r0]                @ release with proper ordering
loop:
    b       loop

    .data
lock:
    .byte   0
    .align  2
```

**Walkthrough:**

1. `ldaexb r1, [r0]` — read current lock state with acquire ordering, arm monitor.
2. Spin if already taken.
3. `stlexb r2, r3, [r0]` — write 1 with release ordering, conditional on the monitor.
4. Release with `STLB` so the *exit* of the critical section also has correct ordering. This is the part that bites people: pairing `LDREXB` with `STLEXB` (mixing acquire-naked and release-paired) silently works on M33 but is wrong portably; use the matched LDAEX/STLEX family throughout an atomic.

## See also

- [STLEXB](STLEXB.md) — required partner.
- [LDREXB](LDREXB.md) — exclusive byte load without acquire.
- [LDAEX](LDAEX.md) / [LDAEXH](LDAEXH.md) — word and half-word variants.
- [LDAB](LDAB.md) — non-exclusive acquire byte load.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.35 — *LDAEXB*.
