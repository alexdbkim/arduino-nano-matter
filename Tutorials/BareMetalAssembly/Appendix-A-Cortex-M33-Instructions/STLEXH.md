# STLEXH — store-release-exclusive of a half-word (ARMv8-M)

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base) — **new in ARMv8-M**
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
STLEXH  <Rd>, <Rt>, [<Rn>]
```

Half-word version of [`STLEX`](STLEX.md). Pairs with [`LDAEXH`](LDAEXH.md).

**When you'd actually use this** closing a 16-bit lock-free RMW that needs release ordering — typical of compact ticket counters, 16-bit refcounts, or version bumps that publish data. Pairs only with `LDAEXH`. Half-word width keeps the field small while preserving full release/acquire ordering with the matching load. Without it, 16-bit atomics would fall back to the wider `STLEX` (wasteful) or to `STREXH`+`DMB` (more code, stronger fence than needed).

## Operands

| Field  | Type             | Constraints                                            |
|--------|------------------|--------------------------------------------------------|
| `<Rd>` | success register | R0–R12, R14. Must differ from `<Rt>` and `<Rn>`.       |
| `<Rt>` | source register  | R0–R12, R14.                                           |
| `<Rn>` | base register    | R0–R12, SP. No offset.                                 |

Address must be half-word aligned.

## Operation (pseudocode)

```text
address = R[n];
if ExclusiveMonitorsPass(address, 2) then
    MemA_with_release[address, 2] = R[t]<15:0>;
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
| T1      | 32-bit | `STLEXH <Rd>, <Rt>, [<Rn>]` — only encoding. |

## Exceptions / faults

- **UsageFault (UNALIGNED)** if address is odd — always.
- BusFault / MemManage / SecureFault as for [`STRH`](STRH.md).

## Example — paired with LDAEXH

### Example 1 — Atomic clear-bit with ordering

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Atomic clear-bit on a 16-bit status with full ordering.
    ldr     r0, =status
    movw    r4, #0xFFFE             @ mask: clear bit 0
clr_loop:
    ldaexh  r1, [r0]
    ands    r1, r1, r4
    stlexh  r2, r1, [r0]
    cmp     r2, #0
    bne     clr_loop
loop:
    b       loop

    .data
    .align  2
status:
    .hword  0x0001
```

**Walkthrough:**

1. `ldaexh r1, [r0]` — acquire-load + arm monitor.
2. `ands r1, r1, r4` — mask off bit 0; `ands` updates flags but the loop only checks R2.
3. `stlexh r2, r1, [r0]` — atomic release-commit. R2 = 0 on success.
4. Retry on contention. This is the part that bites people: `LDAEXH`/`STLEXH` always require half-word alignment — `CCR.UNALIGN_TRP` does not relax them. Always declare 16-bit atomic variables with `.align 2` (or in C, `_Alignas(2)` / `uint16_t` placed in a properly aligned struct).

### Example 2 — Atomic add to 16-bit counter

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Atomically *counter += step on a 16-bit counter, with release ordering.
    ldr     r0, =counter16
    movw    r4, #7                  @ step
add:
    ldaexh  r1, [r0]                @ acquire + arm
    add     r1, r1, r4              @ r1 = counter + step
    uxth    r1, r1                  @ keep result 16-bit
    stlexh  r2, r1, [r0]            @ release + commit
    cmp     r2, #0
    bne     add                 @ contention — retry
loop:
    b       loop

    .data
    .align  2
counter16:
    .hword  0
```

**Walkthrough:**

1. `LDAEXH` reads the 16-bit counter with acquire ordering and arms the monitor.
2. We use `UXTH` to keep the result 16-bit before the conditional store; `STLEXH` only stores the low 16 bits but truncating in-register makes the intent obvious.
3. `STLEXH` commits with release ordering; `CBNZ` retries on contention. Half-word alignment is mandatory — `.align 2` provides it.

## See also

- [LDAEXH](LDAEXH.md) — required partner.
- [STREXH](STREXH.md) — exclusive half-word store without release.
- [STLEX](STLEX.md) / [STLEXB](STLEXB.md) — word and byte variants.
- [STLH](STLH.md) — non-exclusive release half-word store.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.160 — *STLEXH*.
