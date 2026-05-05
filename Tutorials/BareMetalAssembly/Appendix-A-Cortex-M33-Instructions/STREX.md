# STREX — conditional ("exclusive") store of a 32-bit word

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
STREX  <Rd>, <Rt>, [<Rn>{, #<imm>}]
```

Stores `<Rt>` to memory **only** if the local exclusive monitor (armed by a recent matching [`LDREX`](LDREX.md)) is still set. Reports the result in `<Rd>`: 0 = success, 1 = failed.

## Operands

| Field   | Type                 | Constraints                                                |
|---------|----------------------|------------------------------------------------------------|
| `<Rd>`  | success register     | R0–R12, R14. Must differ from `<Rt>` and `<Rn>`.           |
| `<Rt>`  | source register      | R0–R12, R14.                                               |
| `<Rn>`  | base register        | R0–R12, SP.                                                |
| `<imm>` | offset               | imm8 ×4, range 0..1020.                                    |

Address must be word-aligned.

## Operation (pseudocode)

```text
address = R[n] + imm;
if ExclusiveMonitorsPass(address, 4) then
    MemA[address, 4] = R[t];
    R[d] = 0;                @ success
else
    R[d] = 1;                @ failure — memory unchanged
ClearExclusiveMonitors();
@ Flags unchanged.
```

A failing `STREX` does **not** modify memory but does clear the monitor — the next attempt must re-issue `LDREX`.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form                                          |
|---------|--------|-----------------------------------------------|
| T1      | 32-bit | `STREX <Rd>, <Rt>, [<Rn>{, #<imm8*4>}]` — only encoding. |

## Exceptions / faults

- **UsageFault (UNALIGNED)** on non-word-aligned address — always.
- BusFault / MemManage / SecureFault as for [`STR`](STR.md).

## Example — paired with LDREX

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Atomic compare-and-swap of a word: if *r0 == r3 then *r0 = r4.
    ldr     r0, =cell
    movs    r3, #0                  @ expected
    movs    r4, #1                  @ new value
cas_loop:
    ldrex   r1, [r0]
    cmp     r1, r3
    bne     cas_fail                @ value changed under us → bail
    strex   r2, r4, [r0]
    cmp     r2, #0
    bne     cas_loop                @ STREX lost → retry
    @ here: success, r1 = old value (== r3)
    b       done
cas_fail:
    clrex                           @ release monitor without writing
done:
loop:
    b       loop

    .data
    .align  2
cell:
    .word   0
```

**Walkthrough:**

1. The `LDREX` arms the monitor and grabs the current value.
2. `cmp r1, r3 / bne cas_fail` — implement the *compare* half of CAS purely in registers.
3. `strex r2, r4, [r0]` — atomic store. R2 is 0 if we held the line; 1 if anything (interrupt, debug, another bus master) cleared the reservation.
4. The "fail because old != expected" path uses `CLREX` to drop the reservation explicitly. This is the part that bites people: without `CLREX`, you'd leave the monitor armed across a returning interrupt, which doesn't break correctness but keeps reservations alive longer than intended on multi-master systems.

## See also

- [LDREX](LDREX.md) — required partner. Always paired in real code.
- [CLREX](CLREX.md) — explicit "drop the reservation" instruction.
- [STREXB](STREXB.md) / [STREXH](STREXH.md) — byte and half-word variants.
- [STLEX](STLEX.md) — release-semantic exclusive store (v8-M).
- [STR](STR.md) — plain non-exclusive store.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.167 — *STREX*.
