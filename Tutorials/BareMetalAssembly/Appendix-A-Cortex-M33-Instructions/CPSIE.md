# CPSIE — change processor state, enable interrupts (clear PRIMASK or FAULTMASK)

## Class & availability

- **Class:** System
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** Privileged. Unprivileged execution is silently ignored.
- **Secure-state required:** No

## Synopsis

```text
CPSIE <iflags>         @ <iflags> ∈ { i, f, if }
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `i` | flag | Clear `PRIMASK` — re-enables all configurable-priority exceptions |
| `f` | flag | Clear `FAULTMASK` |
| `if` | combo | Clear both |

## Operation (pseudocode)

```text
if Privileged then
    if 'i' in iflags then PRIMASK   = 0
    if 'f' in iflags then FAULTMASK = 0
// else: ignored
// Any IRQ that became pending while masked fires on the next cycle.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `1011 0110 0110 0iif` (`B66x`) |
| T2 | 32-bit | architectural equivalent via `MSR PRIMASK/FAULTMASK, Rn` (`F3Bx 8x00`) |

## Exceptions / faults

- (none) directly. The instruction *immediately following* `CPSIE i` may be preempted if an IRQ was pending — that's the entire point.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Boot path: enable IRQs once the vector table and NVIC are set up
    ldr     r0, =0xE000ED08         @ VTOR
    ldr     r1, =vector_table
    str     r1, [r0]
    dsb
    isb
    cpsie   i                       @ unmask configurable IRQs
loop:
    b   loop

    .section .rodata
    .align 9
vector_table:
    .word 0x20008000                @ initial MSP
    .word reset_handler + 1         @ initial PC (Thumb bit set)
```

**Walkthrough:**

1. `str r1, [r0]` — install the vector table.
2. `dsb` / `isb` — make sure the SCB sees the new VTOR and the pipeline is refetched.
3. `cpsie i` — clears `PRIMASK`. From here, any pending IRQ can fire; the rest of `_start` runs with interrupts on.

This is the part that bites people: enabling IRQs *before* the SP and VTOR are valid is a classic "boots fine until I add a peripheral" bug. Always set up the world first, then `CPSIE i`.

## See also

- [CPSID](CPSID.md) — the matching disable
- [MSR](MSR.md) — fine-grained `BASEPRI` control
- [MRS](MRS.md) — read `PRIMASK`/`FAULTMASK` to save/restore around nested sections

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.36 — *CPS*.
