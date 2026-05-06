# LDAEXH — load-acquire-exclusive of a half-word (ARMv8-M)

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base) — **new in ARMv8-M**
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
LDAEXH  <Rt>, [<Rn>]
```

Half-word version of [`LDAEX`](LDAEX.md). Pairs with [`STLEXH`](STLEXH.md).

**When you'd actually use this** a 16-bit atomic field — typical of compact ticket locks, version counters, or 16-bit refcounts — needs both atomicity and acquire ordering. `LDAEXH` arms the monitor on the half-word and fences subsequent loads, in one instruction. Pairs exclusively with `STLEXH`. The smaller width matters when many such fields are packed into a struct or when targeting RAM-tight devices; the ordering guarantee is identical to `LDAEX`.

## Operands

| Field  | Type                 | Constraints                          |
|--------|----------------------|--------------------------------------|
| `<Rt>` | destination register | R0–R12, R14.                         |
| `<Rn>` | base register        | R0–R12, SP. No offset, no writeback. |

Address must be half-word aligned.

## Operation (pseudocode)

```text
address = R[n];
SetExclusiveMonitors(address, 2);
R[t] = ZeroExtend(MemA_with_acquire[address, 2], 32);
@ Flags unchanged.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form                |
|---------|--------|---------------------|
| T1      | 32-bit | `LDAEXH <Rt>, [<Rn>]` — only encoding. |

## Exceptions / faults

- **UsageFault (UNALIGNED)** if address is odd — always.
- BusFault / MemManage / SecureFault as for [`LDRH`](LDRH.md).

## Example — paired with STLEXH

### Example 1 — Atomic-OR a 16-bit status

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Atomic OR with release/acquire ordering on a 16-bit status word.
    ldr     r0, =status
    movw    r4, #0x0040
or_loop:
    ldaexh  r1, [r0]
    orrs    r1, r1, r4
    stlexh  r2, r1, [r0]
    cmp     r2, #0
    bne     or_loop
loop:
    b       loop

    .data
    .align  2
status:
    .hword  0
```

**Walkthrough:**

1. `ldaexh r1, [r0]` — acquire-load + arm monitor on the 16-bit field.
2. `orrs` — set the desired bit.
3. `stlexh r2, r1, [r0]` — release-store + monitor commit. R2 = 0 on success.
4. Retry on contention. This is the part that bites people: a misaligned `status` symbol would assemble fine but trap at runtime — note the `.align 2` directive in the buffer above.

### Example 2 — CAS on a 16-bit version counter

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ CAS: if *ver == r3 then *ver = r4. Half-word width.
    ldr     r0, =ver
    movw    r3, #0x0001             @ expected
    movw    r4, #0x0002             @ new
cas:
    ldaexh  r1, [r0]                @ acquire + arm
    cmp     r1, r3
    bne     stale
    stlexh  r2, r4, [r0]            @ release + commit
    cmp     r2, #0
    bne     cas                     @ contention — retry
    b       done
stale:
    clrex                           @ expected mismatch — drop monitor
done:
loop:
    b       loop

    .data
    .align  2
ver:
    .hword  0x0001
```

**Walkthrough:**

1. `LDAEXH` acquires and arms; the half-word *must* be aligned to 2 bytes — `.align 2` in the data section guarantees that.
2. If the loaded value does not match `expected`, we drop the reservation with `CLREX`. If it matches, `STLEXH` attempts the release-store and either succeeds or signals contention via `r2`.
3. This is the building block FreeRTOS-style kernels use for 16-bit atomic state transitions.

## See also

- [STLEXH](STLEXH.md) — required partner.
- [LDREXH](LDREXH.md) — exclusive half-word load without acquire.
- [LDAEX](LDAEX.md) / [LDAEXB](LDAEXB.md) — word and byte variants.
- [LDAH](LDAH.md) — non-exclusive acquire half-word load.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.35 — *LDAEXH*.
