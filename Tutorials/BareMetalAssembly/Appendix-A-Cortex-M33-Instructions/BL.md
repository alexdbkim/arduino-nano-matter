# BL — branch with link (call a subroutine via a PC-relative label)

## Class & availability

- **Class:** Branch
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
BL   <label>
```

`BL` is the standard subroutine-call instruction in Thumb. It writes the return address into `LR` (`r14`) and then branches to `<label>`. There is no conditional `BL<cond>` form on Cortex-M; wrap a `BL` in an `IT` block or jump around it with a `B<cond>` if you need conditional calls.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<label>` | PC-relative target | signed 25-bit immediate, range ±16 MB from the current PC |

## Operation (pseudocode)

```text
LR  = (PC_of_next_instruction) | 1   // bit 0 = 1 marks Thumb state
PC  = PC + sign_extend(imm)
```

The `| 1` in `LR` is the part that bites people: the return address you store always has bit 0 set. That's not a real address bit — it's the Thumb-state flag that `BX LR` will consume when you return.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

`BL` never reads or writes APSR flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `BL <label>`, range ±16 MB; only encoding on Cortex-M |

There is no 16-bit `BL` encoding. `BL` is always 4 bytes.

## Exceptions / faults

- `UsageFault (INVSTATE)` if execution somehow lands at an address with bit 0 = 0 (only possible if you hand-craft a bad immediate; the assembler will not produce one).

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ BL demo: call a leaf function that doubles r0
    movs    r0, #21
    bl      times_two       @ LR = address of the next insn, with bit 0 = 1
    @ on return, r0 == 42
loop:
    b       loop

    .thumb_func
times_two:
    lsls    r0, r0, #1      @ r0 <<= 1
    bx      lr              @ return: PC = LR & ~1, ISETSTATE = LR[0]
```

**Walkthrough:**

1. `movs r0, #21` — argument in `r0` per the AAPCS calling convention.
2. `bl times_two` — pushes the return address into `LR` (with bit 0 forced to 1) and jumps.
3. `lsls r0, r0, #1` — the callee does its work, leaving the result in `r0` (return register).
4. `bx lr` — returns. `BX` strips bit 0 to form the PC and uses it to confirm Thumb state.
5. `b loop` — only reached after the call returns, demonstrating linkage worked.

If `times_two` itself called another function, it would have to push `LR` first (`push {lr}` on entry, `pop {pc}` on exit) — leaf functions can skip that.

## See also

- [BX](BX.md) — the other half of a call/return pair (`bx lr` returns).
- [BLX](BLX.md) — call via a register; used for function pointers.
- [B](B.md) — plain branch, no link.
- [IT](IT.md) — wrap a `BL` to make the call itself conditional.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.18 — *BL*.
