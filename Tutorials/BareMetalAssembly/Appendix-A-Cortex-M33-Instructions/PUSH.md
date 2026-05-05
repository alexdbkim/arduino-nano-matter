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

## See also

- [POP](POP.md) — symmetric "pop multiple" / return.
- [STM](STM.md) / [STMDB](STM.md) — the underlying store-multiple operation.
- [STR](STR.md) — single-word store, used for single-register PUSH.
- [LDM](LDM.md) — counterpart for POP.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.94 — *PUSH*.
