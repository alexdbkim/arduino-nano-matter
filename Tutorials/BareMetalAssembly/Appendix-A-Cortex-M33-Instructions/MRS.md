# MRS — move from special register to general-purpose register

## Class & availability

- **Class:** System
- **Architecture:** ARMv8-M Mainline (base); some specials require + Security
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** Privileged for most specials. Unprivileged code can read `APSR`, `IPSR`, `EPSR`, `xPSR`, and `CONTROL` only.
- **Secure-state required:** No for the standard set; Yes for the `_NS` variants (`PRIMASK_NS`, `BASEPRI_NS`, …) which require Secure state with the Security extension.

## Synopsis

```text
MRS  <Rd>, <SYSm>
```

**When you'd actually use this** is whenever you need to read a CPU special register: `IPSR` to identify the active exception inside a fault handler, `CONTROL` to check privilege level and which stack is active, `PSP`/`MSP` to grab a stack pointer for a context switch, or `PRIMASK`/`BASEPRI` to snapshot the interrupt-mask state before changing it. Most specials are privileged-read; unprivileged code can only see `APSR`/`IPSR`/`EPSR`/`CONTROL`. RTOS schedulers lean on `MRS PSP` constantly when saving an outgoing thread's stack pointer into its TCB. There is no other way to reach these registers — they aren't memory-mapped on M-profile.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | `R0`–`R12`, `LR`. Not `SP` or `PC`. |
| `<SYSm>` | special register | `APSR`, `IAPSR`, `EAPSR`, `xPSR`, `IPSR`, `EPSR`, `IEPSR`, `MSP`, `PSP`, `MSPLIM`, `PSPLIM`, `PRIMASK`, `BASEPRI`, `BASEPRI_MAX`, `FAULTMASK`, `CONTROL`, plus `_NS` aliases on Security-enabled cores |

## Operation (pseudocode)

```text
if !PrivilegedRead(SYSm) && CurrentMode == Unprivileged then
    Rd = ReadOnlyView(SYSm)        // EPSR reads as zero, masked fields zero
else
    Rd = SpecialRegister[SYSm]
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags. (Reading `APSR` *into* a GPR doesn't move flags into them as flags — they appear as bits 31..27.)

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1111 0011 1110 1111 1000 dddd ssss ssss` (`F3EF 8xxx`) |

No 16-bit form.

## Exceptions / faults

- Reading `EPSR` returns 0 (architectural).
- No fault on reading an unprivileged-visible special from unprivileged code; reads of privileged specials from unprivileged code return 0.

## Example

### Example 1 — Read state on entry

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Capture the current exception number and stack-pointer choice
    mrs     r0, ipsr            @ r0 = current exception number (0 in thread mode)
    mrs     r1, control         @ r1 bit0 = nPRIV, bit1 = SPSEL, bit2 = FPCA
    mrs     r2, msp             @ r2 = main stack pointer
    mrs     r3, psp             @ r3 = process stack pointer
loop:
    b   loop
```

**Walkthrough:**

1. `mrs r0, ipsr` — `0` in thread mode, otherwise the active exception number; useful inside fault handlers.
2. `mrs r1, control` — tells you whether you're privileged and which stack is active.
3. `mrs r2, msp` / `mrs r3, psp` — read the two stack pointers without committing to either.

This is the part that bites people: `MSP` and `PSP` only mean what you think when you're in the *other* mode — reading the active SP via MRS gives you the same value as reading `SP`, but reading the inactive one via MRS is the only way to see it.

### Example 2 — Save PSP for a context switch

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Sketch of a PendSV-style save: snapshot outgoing thread's PSP
    mrs     r0, psp             @ r0 = process stack pointer
    ldr     r1, =g_outgoing_tcb
    str     r0, [r1]            @ TCB->sp = current PSP
loop:
    b   loop

    .data
    .align 2
g_outgoing_tcb: .word 0
```

**Walkthrough:**

1. `mrs r0, psp` — from handler mode, this is the *only* way to see the thread-mode stack pointer; the active `sp` would point at MSP.
2. `str r0, [r1]` — park PSP in the outgoing thread's TCB so the next switch can restore it.
3. A real PendSV would also push r4–r11 to PSP first (via `stmdb r0!, {r4-r11}`); this is the minimum sketch.
4. Gotcha: from thread mode, `mrs r0, psp` and reading `sp` give the same value when SPSEL=1 — `MRS` is meaningful precisely when you're in the *other* mode.

## See also

- [MSR](MSR.md) — write side; pair `MRS`, modify, `MSR`, then `ISB`
- [CPSID](CPSID.md), [CPSIE](CPSIE.md) — convenience for `PRIMASK`/`FAULTMASK`
- [ISB](ISB.md) — required after writing the result back via MSR

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.95 — *MRS*.
