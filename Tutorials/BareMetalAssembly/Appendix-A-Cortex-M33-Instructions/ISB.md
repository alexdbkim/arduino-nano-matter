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

**When you'd actually use this** — `ISB` flushes the prefetch and forces every following instruction to be fetched fresh, so context-changing operations completed before it (writes to `CONTROL`, `VTOR`, `BASEPRI`, `PRIMASK`, MPU region setup, NVIC priority changes, FPU enable bits) are observed by subsequent instruction execution. Required after writing `SCB->VTOR` (paired with `DSB` first), after switching between MSP and PSP via `MSR CONTROL`, after enabling the MPU, and after self-modifying or freshly-loaded code — without it, already-fetched instructions can still execute under the old context. Versus `DSB` it does *not* wait for memory accesses to finish — it only re-fetches; you almost always want `DSB; ISB` together when both memory and pipeline state need to settle. Versus `DMB` it doesn't order memory at all.

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

### Example 1 — switch from MSP to PSP for thread mode

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

### Example 2 — change SVCall priority via SHPR2, force refetch

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Bump SVCall priority via SHPR2, then make sure subsequent SVCs
    @ observe the new priority — without ISB the next SVC could be
    @ taken at the *old* priority and either escalate or be wrongly masked.
    ldr     r0, =0xE000ED1C         @ SCB->SHPR2
    ldr     r1, [r0]
    bic     r1, r1, #0xFF000000
    orr     r1, r1, #0xC0000000     @ SVCall priority byte
    str     r1, [r0]
    dsb
    isb
    @ next SVC observes the new priority
loop:
    b   loop
```

**Walkthrough:**

1. Read-modify-write the SVCall priority byte in `SHPR2`.
2. `dsb` — make sure the priority write has reached the SCB.
3. `isb` — refetch. Any `SVC` instruction that the pipeline had already speculatively fetched is discarded and re-fetched, so it executes under the new priority. Skipping the `ISB` here is a classic source of "the priority change appeared to take effect intermittently" bugs, where the optimizer's prefetch window happens to straddle the critical instruction.

## See also

- [DSB](DSB.md) — wait for memory accesses to complete (different job)
- [DMB](DMB.md) — order memory accesses without flushing the pipeline
- [MSR](MSR.md) — most common reason you need an ISB

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.79 — *ISB*.
