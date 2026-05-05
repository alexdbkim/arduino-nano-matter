# ISB — instruction synchronisation barrier; flush the pipeline and refetch

## Class & availability

- **Class:** System (barrier)
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
ISB {<option>}         @ option defaults to SY (full system); only SY is defined
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<option>` | barrier domain | `SY` (full system). Other encodings are reserved; assemblers accept the bare `ISB` form. |

## Operation (pseudocode)

```text
// Flush the prefetch and any speculatively decoded instructions.
// Instructions following ISB are fetched fresh from the point of
// the ISB, observing all context-changing operations completed
// before it (CONTROL, VTOR, FAULTMASK/PRIMASK/BASEPRI writes, MPU
// region updates, MSR to special regs, cache/MPU enable bits, …).
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1111 0011 1011 1111 1000 1111 0110 ssss` (`F3BF 8F6s`, `s` = option = `0xF` for SY) |

No 16-bit form.

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
    @ Switch from MSP to PSP for thread mode, then guarantee the
    @ next instruction sees the new stack pointer selection.
    ldr     r0, =0x20008000
    msr     psp, r0
    movs    r0, #0x02       @ CONTROL.SPSEL = 1 (use PSP in thread mode)
    msr     control, r0
    isb                     @ refetch — without this the next push could still use MSP
    movs    r1, #42         @ executed against PSP-based context
loop:
    b   loop
```

**Walkthrough:**

1. `msr psp, r0` — load the process stack pointer.
2. `msr control, r0` — switch the active SP to PSP. By itself this is *architecturally fuzzy* — already-fetched instructions may still use the old context.
3. `isb` — force a refetch. From here on, everything is unambiguously running against PSP.
4. `movs r1, #42` — first "clean" instruction after the switch.

This is the part that bites people: every time you write `CONTROL`, `VTOR`, `MPU_CTRL`, `CCR`, or change the FPU/security state, follow it with `ISB`. Skipping it produces bugs that only show up when the optimizer changes the prefetch window.

## See also

- [DSB](DSB.md) — wait for memory accesses to complete (different job)
- [DMB](DMB.md) — order memory accesses without flushing the pipeline
- [MSR](MSR.md) — most common reason you need an ISB

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.79 — *ISB*.
