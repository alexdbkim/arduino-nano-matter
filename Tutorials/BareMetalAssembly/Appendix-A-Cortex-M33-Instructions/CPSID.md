# CPSID — change processor state, disable interrupts (set PRIMASK or FAULTMASK)

## Class & availability

- **Class:** System
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** Privileged. Unprivileged execution is silently ignored.
- **Secure-state required:** No

## Synopsis

```text
CPSID <iflags>         @ <iflags> ∈ { i, f, if }
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `i` | flag | Set `PRIMASK = 1` — masks all configurable-priority exceptions (every IRQ except NMI and HardFault) |
| `f` | flag | Set `FAULTMASK = 1` — masks all exceptions except NMI; auto-cleared on exception return |
| `if` | combo | Both at once |

## Operation (pseudocode)

```text
if Privileged then
    if 'i' in iflags then PRIMASK   = 1
    if 'f' in iflags then FAULTMASK = 1
// else: ignored
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `1011 0110 0111 0iif` (`B67x`) — `i`-bit and `f`-bit select PRIMASK/FAULTMASK |
| T2 | 32-bit | `MSR PRIMASK/FAULTMASK, Rn` form via `F3Bx 8x00` (architectural equivalent) |

The 16-bit `CPSID` is the canonical encoding; it's much shorter than the equivalent `MOVS Rn, #1; MSR PRIMASK, Rn`.

## Exceptions / faults

- (none).

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Critical section: read-modify-write a shared counter atomically
    ldr     r0, =g_counter
    cpsid   i                   @ disable IRQs (PRIMASK=1)
    ldr     r1, [r0]
    adds    r1, r1, #1
    str     r1, [r0]
    cpsie   i                   @ re-enable IRQs
loop:
    b   loop

    .data
    .align 2
g_counter: .word 0
```

**Walkthrough:**

1. `cpsid i` — sets `PRIMASK`. From this point until `cpsie i`, no configurable IRQ can preempt us; HardFault and NMI still can.
2. The `ldr`/`adds`/`str` triple now executes atomically with respect to interrupts.
3. `cpsie i` — clears `PRIMASK`; any IRQ that became pending during the section fires immediately on the next cycle.

Keep critical sections **short** — every cycle with `PRIMASK=1` adds latency to your real-time IRQs. Prefer `BASEPRI` (via `MSR`) when you only need to mask *low-priority* IRQs.

This is the part that bites people: `CPSID f` is rarely what you want in application code. `FAULTMASK` masks HardFault too, and is auto-cleared by exception return — leaving you to wonder why your guard "vanished".

## See also

- [CPSIE](CPSIE.md) — the matching enable
- [MSR](MSR.md) — write `PRIMASK`/`BASEPRI`/`FAULTMASK` directly with explicit values
- [MRS](MRS.md) — read them back

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.36 — *CPS*.
