# SEV — send event; set the Event Register on every core in the cluster

## Class & availability

- **Class:** Hint
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SEV
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| (none) | — | SEV takes no operands |

## Operation (pseudocode)

```text
// Set the Event Register on this core, and signal an event to all
// other cores in the multiprocessor system. Any core currently in
// WFE wakes up; any core not in WFE simply has its Event Register
// latched to 1 so the next WFE returns immediately.
broadcast_event()
EventRegister = 1
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `1011 1111 0100 0000` (`BF40`) |
| T2 | 32-bit | `1111 0011 1010 1111 1000 0000 0000 0100` (`F3AF 8004`) |

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
    @ Producer side: post work, then wake any waiter sitting in WFE
    ldr     r0, =g_flag
    movs    r1, #1
    str     r1, [r0]        @ publish the work
    dsb                     @ make sure the store is visible first
    sev                     @ wake the consumer in WFE
loop:
    b   loop

    .data
g_flag: .word 0
```

**Walkthrough:**

1. `str r1, [r0]` — publish the shared state.
2. `dsb` — ensure the store has reached memory before we signal; otherwise the woken consumer could still see the old value.
3. `sev` — sets the Event Register everywhere; any consumer parked in `WFE` returns.

On the single-core M33 in the Nano Matter, SEV is most useful inside ISRs to kick a foreground loop that's parked in `WFE`, or paired with `SEVONPEND` for low-power polling. Note `SEV` also sets the *local* Event Register — calling `SEV` then `WFE` immediately is a no-op.

## See also

- [WFE](WFE.md) — the matching wait
- [WFI](WFI.md) — sleeps on IRQs, not events
- [DSB](DSB.md) — pair before SEV when the event implies a memory hand-off

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.165 — *SEV*.
