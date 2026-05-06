# STREX — conditional ("exclusive") store of a 32-bit word

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
STREX  <Rd>, <Rt>, [<Rn>{, #<imm>}]
```

Stores `<Rt>` to memory **only** if the local exclusive monitor (armed by a recent matching [`LDREX`](LDREX.md)) is still set. Reports the result in `<Rd>`: 0 = success, 1 = failed.

**When you'd actually use this** the conditional-store half of every Cortex-M atomic. A successful `STREX` (`Rd = 0`) means our register-only computation has been committed atomically; failure (`Rd = 1`) means a context switch, ISR, or another bus master invalidated the reservation and we must re-issue `LDREX` and retry. This is what backs every lock-free queue, refcount, mutex-acquire and `port.c` scheduler-state write in FreeRTOS / Zephyr / RTX. Without `LDREX`/`STREX`, the only fallback is bracketing the RMW with `CPSID i`/`CPSIE i`, which costs you IRQ latency for every higher-priority handler in the system.

## Operands

| Field   | Type                 | Constraints                                                |
|---------|----------------------|------------------------------------------------------------|
| `<Rd>`  | success register     | R0–R12, R14. Must differ from `<Rt>` and `<Rn>`.           |
| `<Rt>`  | source register      | R0–R12, R14.                                               |
| `<Rn>`  | base register        | R0–R12, SP.                                                |
| `<imm>` | offset               | imm8 ×4, range 0..1020.                                    |

Address must be word-aligned.

## Operation (pseudocode)

```text
address = R[n] + imm;
if ExclusiveMonitorsPass(address, 4) then
    MemA[address, 4] = R[t];
    R[d] = 0;                @ success
else
    R[d] = 1;                @ failure — memory unchanged
ClearExclusiveMonitors();
@ Flags unchanged.
```

A failing `STREX` does **not** modify memory but does clear the monitor — the next attempt must re-issue `LDREX`.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form                                          |
|---------|--------|-----------------------------------------------|
| T1      | 32-bit | `STREX <Rd>, <Rt>, [<Rn>{, #<imm8*4>}]` — only encoding. |

## Exceptions / faults

- **UsageFault (UNALIGNED)** on non-word-aligned address — always.
- BusFault / MemManage / SecureFault as for [`STR`](STR.md).

## Example — paired with LDREX

### Example 1 — Compare-and-swap a word

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Atomic compare-and-swap of a word: if *r0 == r3 then *r0 = r4.
    ldr     r0, =cell
    movs    r3, #0                  @ expected
    movs    r4, #1                  @ new value
cas_loop:
    ldrex   r1, [r0]
    cmp     r1, r3
    bne     cas_fail                @ value changed under us → bail
    strex   r2, r4, [r0]
    cmp     r2, #0
    bne     cas_loop                @ STREX lost → retry
    @ here: success, r1 = old value (== r3)
    b       done
cas_fail:
    clrex                           @ release monitor without writing
done:
loop:
    b       loop

    .data
    .align  2
cell:
    .word   0
```

**Walkthrough:**

1. The `LDREX` arms the monitor and grabs the current value.
2. `cmp r1, r3 / bne cas_fail` — implement the *compare* half of CAS purely in registers.
3. `strex r2, r4, [r0]` — atomic store. R2 is 0 if we held the line; 1 if anything (interrupt, debug, another bus master) cleared the reservation.
4. The "fail because old != expected" path uses `CLREX` to drop the reservation explicitly. This is the part that bites people: without `CLREX`, you'd leave the monitor armed across a returning interrupt, which doesn't break correctness but keeps reservations alive longer than intended on multi-master systems.

### Example 2 — Atomic add to a counter

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Atomically *counter += step.
    ldr     r0, =counter
    movs    r4, #4                  @ step
add:
    ldrex   r1, [r0]                @ arm monitor, r1 = *counter
    add     r1, r1, r4              @ register-side add
    strex   r2, r1, [r0]            @ commit attempt
    cmp     r2, #0
    bne     add                 @ STREX failed — retry
loop:
    b       loop

    .data
    .align  2
counter:
    .word   0
```

**Walkthrough:**

1. `LDREX` reads the counter and arms the monitor.
2. `ADD r1, r1, r4` does the work register-side; nothing has touched memory yet.
3. `STREX` commits if the monitor is still armed; `CBNZ r2, add` is the canonical retry idiom — branches back to re-read whenever the reservation was lost.

## See also

- [LDREX](LDREX.md) — required partner. Always paired in real code.
- [CLREX](CLREX.md) — explicit "drop the reservation" instruction.
- [STREXB](STREXB.md) / [STREXH](STREXH.md) — byte and half-word variants.
- [STLEX](STLEX.md) — release-semantic exclusive store (v8-M).
- [STR](STR.md) — plain non-exclusive store.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.167 — *STREX*.
