# LDREX — exclusive load of a 32-bit word, arming the local exclusive monitor

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
LDREX  <Rt>, [<Rn>{, #<imm>}]
```

Reads a word **and** records the address with the exclusive monitor. A subsequent matching [`STREX`](STREX.md) succeeds only if no other access has invalidated the monitor. This is the building block for atomic read-modify-write sequences.

**When you'd actually use this** the canonical lock-free atomic primitive on Cortex-M — every CAS, atomic-add, atomic bit-set, mutex-take and refcount update in an RTOS kernel boils down to an `LDREX`/`STREX` retry loop (look at FreeRTOS `port.c` `pxCurrentTCB` updates or the `Atomic_*` helpers). Without it, the only way to make a multi-instruction RMW atomic on Cortex-M would be globally disabling interrupts via `CPSID i` — which kills latency for every unrelated higher-priority IRQ. The *load → modify in registers → conditional store → retry on fail* pattern lets the CPU make forward progress under contention without ever blocking interrupts.

## Operands

| Field   | Type                 | Constraints                                                  |
|---------|----------------------|--------------------------------------------------------------|
| `<Rt>`  | destination register | R0–R12, R14.                                                 |
| `<Rn>`  | base register        | R0–R12, SP. PC not allowed.                                  |
| `<imm>` | offset               | imm8 ×4, range 0..1020 (positive, multiple of 4).            |

Address must be word-aligned. No register-offset form, no writeback, no PC-relative form.

## Operation (pseudocode)

```text
address = R[n] + imm;
SetExclusiveMonitors(address, 4);
R[t] = MemA[address, 4];
@ Flags unchanged.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form                                          |
|---------|--------|-----------------------------------------------|
| T1      | 32-bit | `LDREX <Rt>, [<Rn>{, #<imm8*4>}]` — only encoding. |

## Exceptions / faults

- **UsageFault (UNALIGNED)** on non-word-aligned address — always.
- BusFault / MemManage as for [`LDR`](LDR.md).

## Example — must come paired with STREX

### Example 1 — Atomic increment with retry

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Atomic increment of *r0 using LDREX/STREX.
    ldr     r0, =counter
retry:
    ldrex   r1, [r0]                @ arm monitor, r1 = *counter
    adds    r1, r1, #1
    strex   r2, r1, [r0]            @ try to commit; r2 = 0 on success, 1 on fail
    cmp     r2, #0
    bne     retry                   @ monitor lost — retry
    @ at this point r1 holds the new value, *r0 has been updated atomically
    clrex                           @ optional: ensure monitor closed if we leave
loop:
    b       loop

    .data
    .align  2
counter:
    .word   0
```

**Walkthrough:**

1. `ldrex r1, [r0]` — loads `*counter` into R1 *and* tells the local monitor to watch this address.
2. `adds r1, r1, #1` — modify the value in a register; nothing in memory yet.
3. `strex r2, r1, [r0]` — only writes if the monitor is still armed for this address. R2 reports 0 (committed) or 1 (lost — somebody else wrote, or an exception cleared the monitor).
4. `bne retry` — on failure, loop back and re-read. The retry must re-issue `LDREX`; you cannot just skip it. This is the part that bites people: an `STREX` without a *matching, recent* `LDREX` always fails, and any context switch implicitly clears the monitor.

### Example 2 — Atomic bit-set on a flags word

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Atomically OR bit 5 into *flags.
    ldr     r0, =flags
    movs    r4, #(1 << 5)
set_bit:
    ldrex   r1, [r0]                @ arm monitor, r1 = *flags
    orrs    r1, r1, r4              @ set bit 5 in register
    strex   r2, r1, [r0]            @ try to commit
    cmp     r2, #0
    bne     set_bit             @ STREX failed → retry
loop:
    b       loop

    .data
    .align  2
flags:
    .word   0
```

**Walkthrough:**

1. `LDREX` reads `*flags` and arms the monitor.
2. `ORRS` sets bit 5 register-side; nothing in memory yet.
3. `STREX` commits if the monitor is still armed; `CBNZ r2, set_bit` is the idiomatic retry — it tests the success register and re-runs the whole sequence on failure.

## See also

- [STREX](STREX.md) — the conditional store partner. Always pairs with `LDREX`.
- [CLREX](CLREX.md) — explicitly clear the exclusive monitor.
- [LDREXB](LDREXB.md) / [LDREXH](LDREXH.md) — byte and half-word variants.
- [LDAEX](LDAEX.md) — acquire-semantic exclusive load (v8-M).
- [LDR](LDR.md) — non-exclusive plain load.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.36 — *LDREX*.
