# BKPT — software breakpoint; halt to debugger or trigger DebugMonitor/HardFault

## Class & availability

- **Class:** System
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
BKPT #<imm8>           @ imm8 = 0..255, free for the debugger to interpret
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<imm8>` | 8-bit immediate | `0..255`. Visible to the debugger in the DFSR/DEMCR path; common conventions: `#0xAB` = semihosting, `#0` = generic stop. |

## Operation (pseudocode)

```text
if HaltingDebugEnabled (DHCSR.C_DEBUGEN == 1) then
    halt the core, signal DBGRQ to the debugger
else if MonitorDebugEnabled (DEMCR.MON_EN == 1) then
    take DebugMonitor exception
else
    escalate to HardFault (DFSR.BKPT = 1)
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `1011 1110 iiii iiii` (`BExx`) |

No 32-bit form.

## Exceptions / faults

- DebugMonitor exception or HardFault, depending on the debug configuration.
- With a debugger attached (J-Link/CMSIS-DAP via the Nano Matter's USB), the core simply halts and you see the breakpoint in your IDE.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Sanity-check an invariant; halt to debugger if it fails
    movs    r0, #1
    movs    r1, #1
    cmp     r0, r1
    bne     fail
    b       ok
fail:
    bkpt    #0                  @ stop here in the debugger
    b       fail                @ if running free, spin (defensive)
ok:
    movs    r2, #0xAA
loop:
    b   loop
```

**Walkthrough:**

1. `cmp r0, r1` / `bne fail` — the assertion.
2. `bkpt #0` — under a debugger, the core halts here; the debugger shows the failing instruction. With no debugger and `DEMCR.MON_EN=0`, this becomes a HardFault — handy for catching regressions in the field.
3. `b fail` — defensive: if execution somehow continues (e.g. debugger steps over it), don't fall through into `ok`.

This is the part that bites people: a `BKPT` left in production firmware on a board with no debugger attached will HardFault every time it executes. Wrap it in `#ifdef DEBUG` or use it only behind genuine assertion failures.

## See also

- [UDF](UDF.md) — always faults; better choice for "unreachable" traps in release builds
- [SVC](SVC.md) — synchronous trap into SVC_Handler instead
- [DBG](DBG.md) — non-halting trace marker

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.21 — *BKPT*.
