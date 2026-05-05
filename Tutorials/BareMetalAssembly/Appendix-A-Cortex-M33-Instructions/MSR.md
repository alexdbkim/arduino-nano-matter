# MSR — move from general-purpose register to special register

## Class & availability

- **Class:** System
- **Architecture:** ARMv8-M Mainline (base); `_NS` aliases require + Security
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** Privileged for almost every special register. Unprivileged code may only write the application bits of `APSR`.
- **Secure-state required:** No for the standard set; Yes (Secure) to write `_NS` aliases.

## Synopsis

```text
MSR  <SYSm>, <Rn>
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<SYSm>` | special register | `APSR{_nzcvq, _g, _nzcvqg}`, `IAPSR`, `EAPSR`, `xPSR`, `IPSR` (read-only — write ignored), `EPSR` (read-only), `MSP`, `PSP`, `MSPLIM`, `PSPLIM`, `PRIMASK`, `BASEPRI`, `BASEPRI_MAX` (only writes if new value < current), `FAULTMASK`, `CONTROL`, plus `_NS` aliases |
| `<Rn>` | source GPR | `R0`–`R12`, `LR` |

## Operation (pseudocode)

```text
if PrivilegedWrite(SYSm) && CurrentMode != Privileged then
    // write is ignored
else
    SpecialRegister[SYSm] = Rn      // applying field masks per SYSm
// A self-synchronising effect is NOT guaranteed — follow with ISB
// if the next instructions depend on the new context.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | ✓ | ✓ |

Only when writing `APSR`/`xPSR`/`IAPSR`/`EAPSR` with a mask that includes the flag fields. Writes to other specials never touch flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1111 0011 1000 nnnn 1000 mmmm ssss ssss` (`F38n 88ss`, with mask `mmmm`) |

No 16-bit form.

## Exceptions / faults

- Writing a privileged special from unprivileged code is silently ignored, not faulted.
- Writing illegal `CONTROL`/`FAULTMASK` combinations may take effect on the next exception entry/exit — see ARM ARM for the corner cases.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Drop to unprivileged thread mode using PSP, with a fresh PSP value
    ldr     r0, =0x20008000
    msr     psp, r0             @ load process stack pointer
    movs    r0, #0x03           @ CONTROL.nPRIV=1, SPSEL=1
    msr     control, r0         @ unprivileged + PSP
    isb                         @ refetch — required after writing CONTROL
    movs    r1, #0              @ first instruction running unprivileged
loop:
    b   loop
```

**Walkthrough:**

1. `msr psp, r0` — set up PSP before we switch to it; switching first would push onto an undefined stack.
2. `msr control, r0` — flip to unprivileged thread mode using PSP.
3. `isb` — without it, already-prefetched instructions could run with the *old* privilege/stack assumption.
4. `movs r1, #0` — first instruction unambiguously executed in the new context.

This is the part that bites people: forgetting `ISB` after `MSR CONTROL`/`MSR PRIMASK`/`MSR BASEPRI` produces non-deterministic bugs that depend on prefetch state.

## See also

- [MRS](MRS.md) — read side
- [CPSID](CPSID.md), [CPSIE](CPSIE.md) — shorthand for `PRIMASK`/`FAULTMASK`
- [ISB](ISB.md) — pair after every context-changing MSR

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.96 — *MSR*.
