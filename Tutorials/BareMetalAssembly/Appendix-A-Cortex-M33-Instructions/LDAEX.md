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

## See also

- [STLEX](STLEX.md) — required partner.
- [LDREX](LDREX.md) — exclusive load without acquire ordering.
- [LDAEXB](LDAEXB.md) / [LDAEXH](LDAEXH.md) — byte and half-word variants.
- [LDA](LDA.md) — non-exclusive acquire load.
- [CLREX](CLREX.md) — clear the monitor without storing.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.34 — *LDAEX*.
