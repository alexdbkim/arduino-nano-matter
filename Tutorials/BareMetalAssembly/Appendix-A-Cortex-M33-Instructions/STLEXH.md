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

## See also

- [LDAEXH](LDAEXH.md) — required partner.
- [STREXH](STREXH.md) — exclusive half-word store without release.
- [STLEX](STLEX.md) / [STLEXB](STLEXB.md) — word and byte variants.
- [STLH](STLH.md) — non-exclusive release half-word store.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.160 — *STLEXH*.
