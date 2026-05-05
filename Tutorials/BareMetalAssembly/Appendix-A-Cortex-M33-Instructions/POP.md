# POP — pop a list of registers from the (full-descending) stack

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
POP{<cond>}  <reglist>
```

Alias for `LDMIA SP!, <reglist>`. Mirror of [`PUSH`](PUSH.md): registers come back from the lowest-numbered to highest, with PC permitted as a list member to perform a function return in one go.

## Operands

| Field       | Type           | Constraints                                                 |
|-------------|----------------|-------------------------------------------------------------|
| `<reglist>` | register list  | T1: subset of R0–R7, optionally PC. T2: any of R0–R12, LR, PC. |

LR and PC may not both appear in the same `<reglist>`.

## Operation (pseudocode)

```text
address = SP;
for i = 0 to 14
    if reglist<i> == '1' then
        R[i] = MemA[address, 4];
        address = address + 4;
if reglist<15> == '1' then
    LoadWritePC(MemA[address, 4]);    @ interworking branch (function return)
SP = SP + 4*BitCount(reglist);
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form                                                       |
|---------|--------|------------------------------------------------------------|
| T1      | 16-bit | `POP <reglist>` — R0–R7, optionally PC.                    |
| T2 (32) | 32-bit | `POP.W <reglist>` — any subset of R0–R12, LR, PC.          |
| T3 (32) | 32-bit | `POP <Rt>` — single-register form (alias for `LDR Rt, [SP], #4`). |

## Exceptions / faults

- **UsageFault (INVSTATE)** if popped PC has bit 0 = 0 (would switch to ARM state — illegal on M-profile).
- BusFault / MemManage on bad stack memory.
- **SecureFault** when popping into PC that would cross security domains illegally.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ POP demo: typical function epilogue, plus a single-register POP.
    push    {r4, r5, lr}            @ prologue
    movs    r4, #10
    movs    r5, #20
    @ ... work ...
    pop     {r0}                    @ single-reg pop: r0 = *sp; sp += 4 (illustrative)
    pop     {r4, r5, pc}            @ restore r4,r5 and return
loop:
    b       loop
```

**Walkthrough:**

1. `push {r4, r5, lr}` — sets up the frame. (Stand-in prologue.)
2. `pop {r0}` — single-register pop, equivalent to `ldr r0, [sp], #4`. Useful for ad-hoc unwinding.
3. `pop {r4, r5, pc}` — restores R4 and R5, then loads PC from the saved LR slot. Because LR was pushed with bit 0 = 1 (Thumb), the interworking branch returns cleanly. This is the part that bites people: if you `push {lr}` but `pop {lr}` and then `bx lr` separately, you wasted a cycle; popping straight into PC fuses the return.

## See also

- [PUSH](PUSH.md) — symmetric "push multiple".
- [LDM](LDM.md) / [LDMIA](LDM.md) — the underlying load-multiple operation.
- [LDR](LDR.md) — single-word load, used for single-register POP.
- [BX](BX.md) — explicit interworking branch, equivalent to popping into PC.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.93 — *POP*.
