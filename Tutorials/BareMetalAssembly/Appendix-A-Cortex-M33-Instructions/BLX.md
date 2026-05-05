# BLX — branch with link to address held in a register

## Class & availability

- **Class:** Branch
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
BLX   <Rm>
```

`BLX` is the register-indirect call. It writes the return address into `LR` (with bit 0 forced to 1 to mark Thumb) and then branches to `<Rm>`, switching instruction set according to `Rm[0]` — the same rule as `BX`. On Cortex-M33 the only legal value of `Rm[0]` is `1` (Thumb); a `0` raises `UsageFault (INVSTATE)`. There is no `BLX <label>` form on M-profile (that exists only on A/R profiles to switch into ARM state, which Cortex-M doesn't have).

You'll see `BLX` whenever C calls through a function pointer: a vtable, a callback, a HAL driver dispatch table, RTOS task entry trampolines, etc.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rm>` | source register | any of `r0`–`r14`. `BLX PC` is `UNPREDICTABLE`. `Rm[0]` must be 1. |

## Operation (pseudocode)

```text
target = Rm
LR     = (PC_of_next_instruction) | 1
EPSR.T = target<0>
PC     = target & 0xFFFFFFFE
if EPSR.T == 0 then UsageFault(INVSTATE)
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `BLX <Rm>` — only encoding on Cortex-M |

## Exceptions / faults

- `UsageFault (INVSTATE)` if `Rm[0] == 0`.
- `SecureFault` if the target is non-secure and the call is not through a valid SG-gated entry point (Security Extension only).

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ BLX demo: dispatch through a function-pointer table.
    ldr     r0, =handler_table
    movs    r1, #1              @ pick entry 1 (= square)
    ldr     r2, [r0, r1, lsl #2]@ r2 = handler_table[r1]
    movs    r0, #6              @ argument
    blx     r2                  @ call handler_table[1](6) → r0 = 36
loop:
    b       loop

    .thumb_func
identity:
    bx      lr                  @ returns its argument unchanged

    .thumb_func
square:
    muls    r0, r0, r0
    bx      lr

    .align 2
handler_table:
    .word   identity            @ assembler sets bit 0 because of .thumb_func
    .word   square
```

**Walkthrough:**

1. `ldr r0, =handler_table` — load the base of the function-pointer array.
2. `ldr r2, [r0, r1, lsl #2]` — fetch the chosen entry. Each entry is the symbol value the linker stored, *already* ORed with 1 because `square` was declared `.thumb_func`.
3. `blx r2` — jumps to `square`, sets `LR` to the next instruction's address with bit 0 = 1.
4. `muls r0, r0, r0` — the called function squares `r0`.
5. `bx lr` — returns. If anyone had built `handler_table` with raw `&square` (no Thumb bit), `BLX` would fault here on Cortex-M33.

## See also

- [BX](BX.md) — same target rule, no link write.
- [BL](BL.md) — direct call to a label.
- [B](B.md) — plain branch.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.19 — *BLX (register)*.
