# STREXH — conditional exclusive store of a half-word

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
STREXH  <Rd>, <Rt>, [<Rn>]
```

Half-word sibling of [`STREX`](STREX.md). Pairs with [`LDREXH`](LDREXH.md).

**When you'd actually use this** closing a 16-bit atomic RMW — a half-word ticket counter, a compact 16-bit event-flags word, or a 16-bit refcount. Pairs with `LDREXH`. Half-word atomicity is preferred when the field is packed into a struct or shares a cache line with its data. Without `STREXH` you'd widen to 32 bits or disable interrupts globally — both worse for code density and IRQ latency.

## Operands

| Field  | Type                 | Constraints                                            |
|--------|----------------------|--------------------------------------------------------|
| `<Rd>` | success register     | R0–R12, R14. Must differ from `<Rt>` and `<Rn>`.       |
| `<Rt>` | source register      | R0–R12, R14.                                           |
| `<Rn>` | base register        | R0–R12, SP. No offset.                                 |

Address must be half-word aligned.

## Operation (pseudocode)

```text
address = R[n];
if ExclusiveMonitorsPass(address, 2) then
    MemA[address, 2] = R[t]<15:0>;
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
| T1      | 32-bit | `STREXH <Rd>, <Rt>, [<Rn>]` — only form. |

## Exceptions / faults

- **UsageFault (UNALIGNED)** if address is odd — always.
- BusFault / MemManage / SecureFault as for [`STRH`](STRH.md).

## Example — paired with LDREXH

### Example 1 — Atomic-OR a 16-bit status

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Atomic OR of a 16-bit status word with a bitmask.
    ldr     r0, =status
    movw    r4, #0x0008             @ bit to set
or_loop:
    ldrexh  r1, [r0]
    orrs    r1, r1, r4
    strexh  r2, r1, [r0]
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

1. `ldrexh r1, [r0]` — fetch current 16-bit status, arm monitor.
2. `orrs r1, r1, r4` — set the desired bit in a register (the `s` form clobbers flags; safe, since the loop only checks R2 afterwards).
3. `strexh r2, r1, [r0]` — atomic commit. The store stores only the low 16 bits of R1.
4. Retry on failure. This is the part that bites people: an exception between `LDREXH` and `STREXH` will clear the monitor — even if the exception handler doesn't touch `status`. Always assume retries can happen.

### Example 2 — Clear lowest set bit (16-bit)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Atomically clear the lowest set bit in a 16-bit bitmap (x & (x - 1)).
    ldr     r0, =bitmap
clr:
    ldrexh  r1, [r0]                @ arm + read half-word
    subs    r3, r1, #1              @ x - 1
    ands    r1, r1, r3              @ x & (x-1) clears lowest set bit
    uxth    r1, r1
    strexh  r2, r1, [r0]            @ commit
    cmp     r2, #0
    bne     clr                 @ contention — retry
loop:
    b       loop

    .data
    .align  2
bitmap:
    .hword  0x00B4
```

**Walkthrough:**

1. `LDREXH` arms the half-word monitor and reads the bitmap.
2. `x & (x - 1)` is the classic bit-twiddle that clears only the lowest set bit; both operations are register-side.
3. `STREXH` commits the new value atomically; `CBNZ` retries on monitor loss. Half-word alignment is mandatory and provided by `.align 2`.

## See also

- [LDREXH](LDREXH.md) — required partner.
- [STREX](STREX.md) / [STREXB](STREXB.md) — word and byte variants.
- [CLREX](CLREX.md) — drop the monitor without storing.
- [STLEXH](STLEXH.md) — release-semantic exclusive half-word store (v8-M).
- [STRH](STRH.md) — plain half-word store.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.169 — *STREXH*.
