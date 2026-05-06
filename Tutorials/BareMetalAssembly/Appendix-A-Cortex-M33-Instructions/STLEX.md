# STLEX — store-release-exclusive of a 32-bit word (ARMv8-M)

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base) — **new in ARMv8-M**
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
STLEX  <Rd>, <Rt>, [<Rn>]
```

Combines the conditional-store behaviour of [`STREX`](STREX.md) with the release ordering of [`STL`](STL.md). The natural back half of a fully-portable lock-free RMW. Pairs with [`LDAEX`](LDAEX.md).

**When you'd actually use this** closing a lock-free RMW that also needs to *release* prior critical-section writes — the back half of a portable atomic CAS, atomic-add, mutex-give, or refcount update. `STLEX` only commits if the monitor armed by `LDAEX` is still valid, *and* it imposes release ordering, so any earlier stores in the critical section are observed before the lock-update store. C11 compilers emit the `LDAEX`/`STLEX` pair for `atomic_compare_exchange_strong` with `memory_order_acq_rel`. Without it you'd need either `STREX`+`DMB ISH` (clumsy) or `CPSID i` brackets (kills IRQ latency).

## Operands

| Field  | Type             | Constraints                                            |
|--------|------------------|--------------------------------------------------------|
| `<Rd>` | success register | R0–R12, R14. Must differ from `<Rt>` and `<Rn>`.       |
| `<Rt>` | source register  | R0–R12, R14.                                           |
| `<Rn>` | base register    | R0–R12, SP. No offset.                                 |

Address must be word-aligned.

## Operation (pseudocode)

```text
address = R[n];
if ExclusiveMonitorsPass(address, 4) then
    @ release barrier semantics
    MemA_with_release[address, 4] = R[t];
    R[d] = 0;
else
    R[d] = 1;
ClearExclusiveMonitors();
@ Flags unchanged.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form                              |
|---------|--------|-----------------------------------|
| T1      | 32-bit | `STLEX <Rd>, <Rt>, [<Rn>]` — only encoding. |

## Exceptions / faults

- **UsageFault (UNALIGNED)** on non-word-aligned address — always.
- BusFault / MemManage / SecureFault as for [`STR`](STR.md).

## Example — paired with LDAEX

### Example 1 — Atomic CAS with full fences

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Atomic CAS with proper release/acquire fences.
    ldr     r0, =cell
    movs    r3, #0                  @ expected
    movs    r4, #1                  @ new
cas:
    ldaex   r1, [r0]                @ acquire + arm
    cmp     r1, r3
    bne     fail
    stlex   r2, r4, [r0]            @ release + commit
    cmp     r2, #0
    bne     cas
    b       done
fail:
    clrex
done:
loop:
    b       loop

    .data
    .align  2
cell:
    .word   0
```

**Walkthrough:**

1. `ldaex r1, [r0]` — acquire-load and arm monitor.
2. `cmp r1, r3 / bne fail` — if value isn't what we expected, bail without writing.
3. `stlex r2, r4, [r0]` — atomic release-store. Any prior memory writes are observed by others before this store. R2 = 0 on success.
4. The `clrex` on the fail path drops the reservation cleanly. This is the part that bites people: pairing `LDREX` with `STLEX` (or `LDAEX` with `STREX`) is legal but defeats the matched ordering — always pair LDAEX↔STLEX or LDREX↔STREX in a single atomic.

### Example 2 — Ticket-lock fetch-and-add

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Atomically: ticket = next; next = next + 1; (return ticket in r1)
    ldr     r0, =next_ticket
fa:
    ldaex   r1, [r0]                @ acquire + arm; r1 = old ticket
    adds    r4, r1, #1              @ r4 = ticket + 1
    stlex   r2, r4, [r0]            @ release + commit
    cmp     r2, #0
    bne     fa                  @ contention — retry
loop:
    b       loop

    .data
    .align  2
next_ticket:
    .word   0
```

**Walkthrough:**

1. `LDAEX` snapshots the next-ticket counter, arming the monitor and acquire-fencing subsequent reads.
2. We compute `ticket+1` in a *separate* register so `r1` keeps the old value (this thread's ticket).
3. `STLEX` writes the bumped counter with release ordering. `CBNZ r2, fa` retries the whole sequence on contention — classic Bakery/ticket lock entry code.

## See also

- [LDAEX](LDAEX.md) — required partner.
- [STREX](STREX.md) — exclusive store without release.
- [STLEXB](STLEXB.md) / [STLEXH](STLEXH.md) — byte and half-word variants.
- [STL](STL.md) — non-exclusive release-store.
- [CLREX](CLREX.md) — clear monitor without storing.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.158 — *STLEX*.
