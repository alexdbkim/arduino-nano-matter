# LDREXH — exclusive load of a half-word, arming the local exclusive monitor

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
LDREXH  <Rt>, [<Rn>]
```

Half-word sibling of [`LDREX`](LDREX.md). Pairs with [`STREXH`](STREXH.md) to atomically RMW a 16-bit field.

**When you'd actually use this** a 16-bit shared field — ticket counter, compact mutex, version number — needs atomic RMW without growing to 32 bits. `LDREXH`/`STREXH` give you half-word atomicity at the cost of strict 2-byte alignment on the address. Common in compact RTOS objects (e.g. a 16-bit `event_group` flag word) where every byte counts. Without these, you'd either widen to 32 bits or fall back to global interrupt disable — both worse.

## Operands

| Field  | Type                 | Constraints              |
|--------|----------------------|--------------------------|
| `<Rt>` | destination register | R0–R12, R14.             |
| `<Rn>` | base register        | R0–R12, SP. No offset.   |

Address must be half-word aligned.

## Operation (pseudocode)

```text
address = R[n];
SetExclusiveMonitors(address, 2);
R[t] = ZeroExtend(MemA[address, 2], 32);
@ Flags unchanged.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form                              |
|---------|--------|-----------------------------------|
| T1      | 32-bit | `LDREXH <Rt>, [<Rn>]` — only form.|

## Exceptions / faults

- **UsageFault (UNALIGNED)** if address is odd — always traps regardless of `CCR.UNALIGN_TRP`.
- BusFault / MemManage / SecureFault as for [`LDRH`](LDRH.md).

## Example — must come paired with STREXH

### Example 1 — Saturating add on 16-bit

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Atomically saturate-add 1 to a 16-bit counter, capping at 0xFFFF.
    ldr     r0, =hcounter
retry:
    ldrexh  r1, [r0]
    cmp     r1, #0xFF00
    bhs     skip                    @ near top — bail out
    adds    r1, r1, #1
skip:
    strexh  r2, r1, [r0]
    cmp     r2, #0
    bne     retry
loop:
    b       loop

    .data
    .align  2
hcounter:
    .hword  0
```

**Walkthrough:**

1. `ldrexh r1, [r0]` — atomic half-word read, monitor armed.
2. `cmp r1, #0xFF00 / bhs skip` — branch over the increment to handle the saturation case in pure-register code.
3. `strexh r2, r1, [r0]` — commit attempt. Even if we *didn't* modify R1, we still need the matching exclusive store to release the reservation cleanly when retrying.
4. `bne retry` — replay the whole sequence on failure. This is the part that bites people: nesting two LDREX/STREX pairs (e.g. word + halfword on the same address) gives undefined behaviour — the monitor only tracks one reservation per CPU.

### Example 2 — CAS on 16-bit ticket counter

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Compare-and-swap on a 16-bit ticket: if *t == r3 then *t = r4.
    ldr     r0, =ticket
    movw    r3, #0x0010             @ expected
    movw    r4, #0x0011             @ new
cas:
    ldrexh  r1, [r0]                @ arm + read half-word
    cmp     r1, r3
    bne     mismatch
    strexh  r2, r4, [r0]            @ commit
    cmp     r2, #0
    bne     cas                 @ contention → retry
    b       done
mismatch:
    clrex                           @ drop reservation explicitly
done:
loop:
    b       loop

    .data
    .align  2
ticket:
    .hword  0x0010
```

**Walkthrough:**

1. `LDREXH` arms the half-word monitor and reads the current ticket.
2. On expected-mismatch we `CLREX` to drop the reservation cleanly.
3. On match, `STREXH` commits and `CBNZ` retries the whole CAS if the monitor was lost — typical multi-producer ticket-grab pattern.

## See also

- [STREXH](STREXH.md) — required partner.
- [LDREX](LDREX.md) / [LDREXB](LDREXB.md) — word and byte variants.
- [CLREX](CLREX.md) — explicit monitor clear.
- [LDAEXH](LDAEXH.md) — acquire-semantic exclusive half-word load (v8-M).
- [LDRH](LDRH.md) — non-exclusive half-word load.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.38 — *LDREXH*.
