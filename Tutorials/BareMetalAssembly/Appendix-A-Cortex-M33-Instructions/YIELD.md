# YIELD — hint that this thread is in a spin and could be descheduled

## Class & availability

- **Class:** Hint
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
YIELD
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| (none) | — | YIELD takes no operands |

## Operation (pseudocode)

```text
// Hint that the current task is doing nothing useful (typically a
// spinlock or busy-wait) and another thread, if any, could run.
// On bare-metal Cortex-M33 with no SMT/hyperthreading and no OS
// hook, this executes as a NOP. An RTOS may trap it via a fault
// handler or simply ignore it.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `1011 1111 0001 0000` (`BF10`) |
| T2 | 32-bit | `1111 0011 1010 1111 1000 0000 0000 0001` (`F3AF 8001`) |

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
    @ Spin on a flag set by an ISR, hinting we're idle in the loop
    ldr     r0, =g_flag
1:  ldr     r1, [r0]
    cbnz    r1, 2f
    yield                   @ "I'm just spinning" — NOP on bare M33
    b       1b
2:  @ flag is set, proceed
loop:
    b   loop

    .data
g_flag: .word 0
```

**Walkthrough:**

1. `ldr r1, [r0]` — sample the shared flag.
2. `cbnz r1, 2f` — exit the spin once it goes non-zero.
3. `yield` — hint to the implementation. On the Nano Matter's M33 it's architecturally a NOP, but it documents intent and is free to keep around if the code ever moves to an RTOS that hooks it.

For real power savings on this chip, prefer `WFE`/`WFI` — `YIELD` does **not** reduce current.

## See also

- [NOP](NOP.md) — what YIELD effectively is on bare-metal M33
- [WFE](WFE.md) — actually sleep instead of spinning
- [WFI](WFI.md) — sleep until an interrupt

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.319 — *YIELD*.
