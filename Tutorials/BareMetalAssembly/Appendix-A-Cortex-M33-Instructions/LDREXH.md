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

## See also

- [STREXH](STREXH.md) — required partner.
- [LDREX](LDREX.md) / [LDREXB](LDREXB.md) — word and byte variants.
- [CLREX](CLREX.md) — explicit monitor clear.
- [LDAEXH](LDAEXH.md) — acquire-semantic exclusive half-word load (v8-M).
- [LDRH](LDRH.md) — non-exclusive half-word load.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.38 — *LDREXH*.
