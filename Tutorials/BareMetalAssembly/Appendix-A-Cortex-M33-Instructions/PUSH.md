# PUSH — push a list of registers onto the (full-descending) stack

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
PUSH{<cond>}  <reglist>
```

Alias for `STMDB SP!, <reglist>`. Lowest-numbered register is stored at the *lowest* address (i.e. ends up nearest the new top-of-stack).

## Operands

| Field       | Type           | Constraints                                                 |
|-------------|----------------|-------------------------------------------------------------|
| `<reglist>` | register list  | T1: subset of R0–R7, optionally LR. T2: any of R0–R12 + LR. |

PC cannot be pushed. SP cannot be pushed.

**When you'd actually use this**: the function prologue, every time a non-leaf function or one that uses callee-saved registers (R4–R11) starts up — `PUSH {r4-r7, lr}` saves the registers AAPCS says you must preserve, plus the return address, in one instruction. Inside an ISR that needs to call a C subroutine, you'll also `PUSH {r0-r3, lr}` to protect the caller-saved registers across the call (the hardware-stacked frame only covers the original interruption, not your nested call). Without `PUSH` you'd write four to eight individual `STR Rx, [SP, #-4]!` instructions plus manual SP arithmetic — slower, larger, and easier to get wrong on the matching `POP`/`LDM` epilogue.

## Operation (pseudocode)

```text
address = SP - 4*BitCount(reglist);
for i = 0 to 14
    if reglist<i> == '1' then
        MemA[address, 4] = R[i];
        address = address + 4;
SP = SP - 4*BitCount(reglist);
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form                                                          |
|---------|--------|---------------------------------------------------------------|
| T1      | 16-bit | `PUSH <reglist>` — R0–R7, optionally LR.                      |
| T2 (32) | 32-bit | `PUSH.W <reglist>` — any subset of R0–R12 plus LR.            |
| T3 (32) | 32-bit | `PUSH <Rt>` — single-register form (alias for `STR Rt, [SP, #-4]!`). |

## Exceptions / faults

- **UsageFault (STKOF)** if the stack-limit register is configured and SP would drop below it.
- **MemManage** / **BusFault** if the new stack region is inaccessible.
- **UsageFault (UNALIGNED)** is impossible if SP was 8-byte-aligned per AAPCS, but a misaligned SP plus `CCR.UNALIGN_TRP` will trap.

## Example

### Example 1 — Classic prologue and epilogue

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ PUSH demo: classic prologue/epilogue around a leaf-ish function call.
    push    {r4, r5, r6, r7, lr}    @ save callee-saved + return address
    movs    r4, #1
    movs    r5, #2
    @ ... do work using r4..r7 freely ...
    pop     {r4, r5, r6, r7, pc}    @ restore and return in one go
loop:
    b       loop
```

**Walkthrough:**

1. `push {r4, r5, r6, r7, lr}` — SP drops by 20 first, then R4 lands at the *lowest* address, R5 next, …, LR at the highest. This is the standard AAPCS function prologue.
2. The body freely clobbers R4..R7 because they're saved.
3. `pop {r4, r5, r6, r7, pc}` — restores the four work registers and pulls the saved LR straight into PC, performing the function return as a single instruction. This is the part that bites people: pushing LR but popping into PC is what makes the matched pair an actual return — and it's an interworking branch, so the LSB of the value being popped into PC must be 1 (Thumb).

### Example 2 — ISR-local save before calling a C helper

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Simulate an IRQ handler that must call a C function.
    push    {r0-r3, r12, lr}    @ protect caller-saved across the BL
    bl      handle_event        @ C callee may clobber r0-r3, r12
    pop     {r0-r3, r12, lr}    @ restore originals
    bx      lr                  @ EXC_RETURN (in lr) unwinds the IRQ
loop:
    b       loop

    .thumb_func
handle_event:
    bx      lr
```

**Walkthrough:**

1. Hardware stacking on exception entry only saves `r0-r3, r12, lr, pc, xpsr` for the *interrupted* context — anything our handler is itself using around a `BL` must be saved by us.
2. `PUSH {r0-r3, r12, lr}` is six registers = 24 bytes; SP stays 8-byte aligned (AAPCS) because we pushed an even number of words.
3. The matching `POP` puts the original `EXC_RETURN` magic value back into `lr`; `bx lr` then performs the proper exception unwind, restoring the pre-interrupt state.

## See also

- [POP](POP.md) — symmetric "pop multiple" / return.
- [STM](STM.md) / [STMDB](STM.md) — the underlying store-multiple operation.
- [STR](STR.md) — single-word store, used for single-register PUSH.
- [LDM](LDM.md) — counterpart for POP.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.94 — *PUSH*.
