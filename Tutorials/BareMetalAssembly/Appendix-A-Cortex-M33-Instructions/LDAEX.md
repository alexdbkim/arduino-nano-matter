# LDAEX — load-acquire-exclusive of a 32-bit word (ARMv8-M)

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base) — **new in ARMv8-M**
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
LDAEX  <Rt>, [<Rn>]
```

Combines the monitor-arming behaviour of [`LDREX`](LDREX.md) with the acquire ordering of [`LDA`](LDA.md). The natural front half of a fully-portable lock-free RMW. Pairs with [`STLEX`](STLEX.md).

**When you'd actually use this** the front half of a portable lock-free RMW that also needs *acquire* ordering — taking a spinlock, or implementing `atomic_compare_exchange_strong` with `memory_order_acq_rel`. `LDAEX` arms the exclusive monitor *and* fences subsequent loads inside the critical section, so reads of lock-protected data cannot drift above the lock-take. Pair always with `STLEX` so both halves of the RMW carry matching ordering. Without LDAEX/STLEX you'd reach for `CPSID i`/`CPSIE i` brackets, which kill IRQ latency for unrelated higher-prio interrupts.

## Operands

| Field  | Type                 | Constraints                          |
|--------|----------------------|--------------------------------------|
| `<Rt>` | destination register | R0–R12, R14.                         |
| `<Rn>` | base register        | R0–R12, SP. No offset, no writeback. |

Address must be word-aligned.

## Operation (pseudocode)

```text
address = R[n];
SetExclusiveMonitors(address, 4);
R[t] = MemA_with_acquire[address, 4];
@ Flags unchanged.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form               |
|---------|--------|--------------------|
| T1      | 32-bit | `LDAEX <Rt>, [<Rn>]` — only encoding. |

## Exceptions / faults

- **UsageFault (UNALIGNED)** on non-word-aligned address — always.
- BusFault / MemManage / SecureFault as for [`LDR`](LDR.md).

## Example — paired with STLEX

### Example 1 — Atomic-increment with full fences

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Atomic increment with full release/acquire fences for free.
    ldr     r0, =counter
retry:
    ldaex   r1, [r0]                @ acquire + arm monitor
    adds    r1, r1, #1
    stlex   r2, r1, [r0]            @ release + commit; r2 = 0/1
    cmp     r2, #0
    bne     retry
loop:
    b       loop

    .data
    .align  2
counter:
    .word   0
```

**Walkthrough:**

1. `ldaex r1, [r0]` — acquire-loads, plus arms the exclusive monitor for `*counter`.
2. The increment is plain register arithmetic.
3. `stlex r2, r1, [r0]` — releases (so any prior writes are visible to other observers) and commits if the monitor still holds. R2 = success flag.
4. The retry loop is the same structure as [`LDREX`](LDREX.md)/[`STREX`](STREX.md). This is the part that bites people: don't mix LDAEX/STREX or LDREX/STLEX in the same atomic — always pair acquire with release variants of the *same* width.

### Example 2 — Spinlock take with acquire+release

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Take a word-sized spinlock: 0 = free, 1 = held.
    ldr     r0, =spinlock
    movs    r3, #1
take:
    ldaex   r1, [r0]                @ acquire + arm monitor
    cmp     r1, #0
    bne     take                    @ already held — spin
    stlex   r2, r3, [r0]            @ release + commit "1"
    cmp     r2, #0
    bne     take                    @ contention — retry
loop:
    b       loop

    .data
    .align  2
spinlock:
    .word   0
```

**Walkthrough:**

1. `LDAEX` reads the lock word, arms the monitor, and gives acquire ordering — so any code that runs after the lock is taken cannot see stale critical-section data from a prior holder.
2. `STLEX` writes the new value `1` if the monitor is still armed; release ordering ensures the prior holder's writes are observed before our subsequent reads.
3. Mixing `LDAEX` with plain `STREX` (or `LDREX` with `STLEX`) silently works on M33 but is non-portable — always pair acquire-with-release of the same width.

## See also

- [STLEX](STLEX.md) — required partner.
- [LDREX](LDREX.md) — exclusive load without acquire ordering.
- [LDAEXB](LDAEXB.md) / [LDAEXH](LDAEXH.md) — byte and half-word variants.
- [LDA](LDA.md) — non-exclusive acquire load.
- [CLREX](CLREX.md) — clear the monitor without storing.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.34 — *LDAEX*.
