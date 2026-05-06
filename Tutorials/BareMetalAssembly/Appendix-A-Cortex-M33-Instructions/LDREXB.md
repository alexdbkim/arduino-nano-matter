# LDREXB — exclusive load of a byte, arming the local exclusive monitor

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
LDREXB  <Rt>, [<Rn>]
```

Byte-sized sibling of [`LDREX`](LDREX.md). Reads one byte (zero-extended) and arms the monitor for byte-grained atomic RMW. Pairs with [`STREXB`](STREXB.md).

**When you'd actually use this** an 8-bit refcount or a one-byte lock packed into a struct needs atomic RMW. Byte width matters when many such fields share a cache line or struct, or when targeting RAM-tight code. `LDREXB`/`STREXB` give you single-byte atomicity without bumping the field to 32 bits and without disabling interrupts. The monitor tracks the same address granularity as the larger variants — there is exactly *one* reservation per CPU, so you cannot nest a byte and a word atomic on the same line.

## Operands

| Field  | Type                 | Constraints              |
|--------|----------------------|--------------------------|
| `<Rt>` | destination register | R0–R12, R14.             |
| `<Rn>` | base register        | R0–R12, SP. No offset.   |

No immediate offset, no register offset, no writeback.

## Operation (pseudocode)

```text
address = R[n];
SetExclusiveMonitors(address, 1);
R[t] = ZeroExtend(MemA[address, 1], 32);
@ Flags unchanged.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form                              |
|---------|--------|-----------------------------------|
| T1      | 32-bit | `LDREXB <Rt>, [<Rn>]` — only form.|

## Exceptions / faults

- BusFault / MemManage / SecureFault as for [`LDRB`](LDRB.md). Byte access — no UNALIGNED.

## Example — must come paired with STREXB

### Example 1 — Atomic byte-flag toggle

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Atomic byte-flag toggle.
    ldr     r0, =flag
retry:
    ldrexb  r1, [r0]                @ r1 = *flag (zero-extended)
    eors    r1, r1, #1              @ toggle bit 0
    strexb  r2, r1, [r0]            @ commit; r2 = 0 success, 1 fail
    cmp     r2, #0
    bne     retry
loop:
    b       loop

    .data
flag:
    .byte   0
    .align  2
```

**Walkthrough:**

1. `ldrexb r1, [r0]` — exclusive byte read, monitor armed.
2. `eors r1, r1, #1` — register-side modify (toggle bit 0). Note `eors` updates flags, but the atomic protocol uses only R2 for the success result.
3. `strexb r2, r1, [r0]` — atomic commit; R2 = 0 means success, 1 means another agent stole the line and we must retry.
4. `bne retry` — re-issue the `LDREXB` on failure. This is the part that bites people: every retry needs a *fresh* `LDREXB`; replaying just the `STREXB` is guaranteed to fail.

### Example 2 — Refcount decrement-and-test-zero

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Atomically refcount--; branch to free_path if it hit zero.
    ldr     r0, =refcount
dec:
    ldrexb  r1, [r0]                @ arm + read byte
    subs    r1, r1, #1              @ decrement (flags set)
    strexb  r2, r1, [r0]            @ commit
    cmp     r2, #0
    bne     dec                 @ retry on contention
    cmp     r1, #0
    beq     free_path               @ last reference dropped
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

1. `LDREXB` reads the byte refcount and arms the byte monitor.
2. `SUBS` decrements register-side; no memory traffic yet.
3. `STREXB` commits atomically; on success we test the post-decrement value and dispatch to the cleanup path if it just hit zero. The decrement and the zero-test together are the classic last-reference idiom used in every shared-resource refcount.

## See also

- [STREXB](STREXB.md) — required partner.
- [LDREX](LDREX.md) / [LDREXH](LDREXH.md) — word and half-word variants.
- [CLREX](CLREX.md) — clear the monitor explicitly.
- [LDAEXB](LDAEXB.md) — acquire-semantic exclusive byte load (v8-M).
- [LDRB](LDRB.md) — non-exclusive byte load.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.37 — *LDREXB*.
