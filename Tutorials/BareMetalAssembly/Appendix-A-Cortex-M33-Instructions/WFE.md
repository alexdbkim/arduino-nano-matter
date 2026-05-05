# WFE — wait for event; sleep until the Event Register is set

## Class & availability

- **Class:** Hint
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
WFE
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| (none) | — | WFE takes no operands |

## Operation (pseudocode)

```text
if EventRegister == 1 then
    EventRegister = 0       // consume the event, do not sleep
else
    enter low-power state until any of:
        - SEV from this or another core
        - an enabled IRQ becomes pending
        - SCR.SEVONPEND=1 and any IRQ becomes pending
        - a debug or external event
    EventRegister stays 0 on wake (event was consumed by the wake)
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `1011 1111 0010 0000` (`BF20`) |
| T2 | 32-bit | `1111 0011 1010 1111 1000 0000 0000 0010` (`F3AF 8002`) |

## Exceptions / faults

- (none) directly.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Wait until a producer signals work is ready (g_flag != 0)
    ldr     r0, =g_flag
1:  ldr     r1, [r0]
    cbnz    r1, 2f
    wfe                     @ sleep until SEV or IRQ
    b       1b
2:  @ work is ready — handle it
    movs    r1, #0
    str     r1, [r0]
loop:
    b   loop

    .data
g_flag: .word 0
```

**Walkthrough:**

1. `ldr r1, [r0]` — read the shared flag.
2. `cbnz r1, 2f` — if non-zero, skip the sleep.
3. `wfe` — sleep on the Event Register; another context (ISR, or another bus master) calls `SEV` to wake us.
4. After waking, loop and re-check the flag — WFE can wake spuriously, so always re-test the predicate.

The Cortex-M33 in the Nano Matter is single-core, so the classic SMP "wake the other CPU" use case doesn't apply. WFE is still useful here as a low-power spin: set `SCR.SEVONPEND = 1` and WFE wakes on any pending IRQ even when masked — handy for polling loops without burning current.

## See also

- [SEV](SEV.md) — the matching "wake up" instruction
- [WFI](WFI.md) — sleep on IRQs only; ignores the Event Register
- [DSB](DSB.md) — drain writes before sleeping

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.308 — *WFE*.
