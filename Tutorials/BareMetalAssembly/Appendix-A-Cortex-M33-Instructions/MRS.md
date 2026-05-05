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

## See also

- [MSR](MSR.md) — write side; pair `MRS`, modify, `MSR`, then `ISB`
- [CPSID](CPSID.md), [CPSIE](CPSIE.md) — convenience for `PRIMASK`/`FAULTMASK`
- [ISB](ISB.md) — required after writing the result back via MSR

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.95 — *MRS*.
