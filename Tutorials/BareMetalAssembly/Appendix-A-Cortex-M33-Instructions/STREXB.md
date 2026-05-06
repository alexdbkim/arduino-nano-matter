# STREXB — conditional exclusive store of a byte

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
STREXB  <Rd>, <Rt>, [<Rn>]
```

Byte sibling of [`STREX`](STREX.md). Pairs with [`LDREXB`](LDREXB.md) for atomic byte RMW.

**When you'd actually use this** the byte-wide back half of an atomic RMW — closing a byte-spinlock take, an atomic byte refcount step, or a state-machine transition where the lock/state lives in a single packed byte. Pairs with `LDREXB`. Common in RTOS objects where many narrow lock or counter fields share a cache line. Without `LDREXB`/`STREXB` you'd widen the field to 32 bits or fall back to global interrupt disable — both wasteful.

## Operands

| Field  | Type                 | Constraints                                            |
|--------|----------------------|--------------------------------------------------------|
| `<Rd>` | success register     | R0–R12, R14. Must differ from `<Rt>` and `<Rn>`.       |
| `<Rt>` | source register      | R0–R12, R14.                                           |
| `<Rn>` | base register        | R0–R12, SP. No offset.                                 |

## Operation (pseudocode)

```text
address = R[n];
if ExclusiveMonitorsPass(address, 1) then
    MemA[address, 1] = R[t]<7:0>;
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

| Variant | Width  | Form                                  |
|---------|--------|---------------------------------------|
| T1      | 32-bit | `STREXB <Rd>, <Rt>, [<Rn>]` — only form. |

## Exceptions / faults

- BusFault / MemManage / SecureFault as for [`STRB`](STRB.md). Byte access — no UNALIGNED.

## Example — paired with LDREXB

### Example 1 — Byte test-and-set mutex

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Atomic test-and-set on a byte lock.
    ldr     r0, =mutex
acquire:
    ldrexb  r1, [r0]                @ r1 = current lock byte
    cmp     r1, #0
    bne     acquire                 @ already held — spin
    movs    r2, #1
    strexb  r3, r2, [r0]            @ try to set; r3 = 0 success, 1 fail
    cmp     r3, #0
    bne     acquire                 @ contention — retry
    @ critical section here ...
    movs    r2, #0
    strb    r2, [r0]                @ release (plain store ok if holder is sole writer)
loop:
    b       loop

    .data
mutex:
    .byte   0
    .align  2
```

**Walkthrough:**

1. `ldrexb r1, [r0]` — read current state, arm monitor.
2. `cmp / bne acquire` — if already locked, spin-loop on the load (no `STREXB` needed; `LDREXB` re-arms the monitor each time).
3. `strexb r3, r2, [r0]` — atomic "set to 1". R3 reports success.
4. `bne acquire` — failure means another core/thread won the race. Try again. This is the part that bites people: forgetting that an interrupt between `LDREXB` and `STREXB` can clear the monitor and force a retry — that's by design, not a bug.

### Example 2 — Atomic byte refcount decrement

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Refcount byte: atomically decrement, branch to free_path if it hit zero.
    ldr     r0, =refcount
dec:
    ldrexb  r1, [r0]                @ arm + read byte
    subs    r1, r1, #1              @ register-side decrement
    strexb  r2, r1, [r0]            @ commit
    cmp     r2, #0
    bne     dec                 @ contention — retry
    cmp     r1, #0
    beq     free_path
    b       done
free_path:
done:
loop:
    b       loop

    .data
refcount:
    .byte   3
    .align  2
```

**Walkthrough:**

1. `LDREXB` arms the byte monitor and reads the current count.
2. `SUBS` decrements register-side and `STREXB` commits atomically — `CBNZ` retries on contention.
3. After a successful commit we test the post-decrement value: hitting zero means we held the last reference and must run the cleanup path. The decrement-and-test-zero idiom is at the heart of every shared-resource lifetime.

## See also

- [LDREXB](LDREXB.md) — required partner.
- [STREX](STREX.md) / [STREXH](STREXH.md) — word and half-word variants.
- [CLREX](CLREX.md) — release the reservation without storing.
- [STLEXB](STLEXB.md) — release-semantic exclusive byte store (v8-M).
- [STRB](STRB.md) — plain byte store (use to release a lock cleanly).

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.168 — *STREXB*.
