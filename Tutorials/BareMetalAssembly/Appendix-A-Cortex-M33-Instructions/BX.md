# BX — branch to address held in a register (no link)

## Class & availability

- **Class:** Branch
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
BX   <Rm>
```

**When you'd actually use this**: `BX` is the canonical way to **return** from a subroutine on Cortex-M (`bx lr`). It's also how you tail-jump through a function pointer when you don't need `LR` saved, and how exception handlers return — except there the magic `EXC_RETURN` value in `LR` is consumed by the hardware to unwind the exception frame instead of branching to ordinary code. Without `BX`, you'd be tempted to write `MOV PC, LR`, but that doesn't update the Thumb-state bit and would crash on Cortex-M. The `Rm[0] == 1` rule is the same trap as `BLX`.

`BX` jumps to the address in `<Rm>`. The low bit of `<Rm>` selects the instruction-set state that the core enters: `1` = Thumb, `0` = ARM (A32). **Cortex-M33 only implements Thumb**, so the LSB *must* be `1`. If it isn't, you take a `UsageFault` with `INVSTATE` set the moment you try to execute the target instruction.

This is the part that bites people most often when:

- they jump to a function address that came from a `.word` table they hand-built without `+1`;
- they OR an entry-point with `0` instead of `1` when constructing a vector;
- they copy a function pointer out of a struct that was filled in with the raw symbol address rather than the address-of-Thumb-function value the linker emits.

The assembler/linker put the `1` bit there for you when you write `LDR Rx, =func` or use a `.thumb_func` symbol. If you compute an address yourself, you must `ORR Rx, Rx, #1` before `BX`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rm>` | source register | any of `r0`–`r15`. `BX LR` is the canonical return. `BX PC` is legal but rarely useful. |

## Operation (pseudocode)

```text
target = Rm
EPSR.T = target<0>          // 1 → stay in Thumb (only legal value on M-profile)
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
| T1 | 16-bit | `BX <Rm>` — only encoding |

## Exceptions / faults

- `UsageFault (INVSTATE)` if `Rm[0] == 0` (target is not Thumb).
- On Cortex-M with the Security Extension, `BX` to a non-secure address from secure state goes through the SAU/IDAU and may raise a `SecureFault`.

## Example

### Example 1 — BX LR return + BLX indirect call

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ BX demo 1: classic function return via BX LR.
    bl      add_one         @ LR = return address (bit 0 = 1)
    @ r0 now holds 8

    @ BX demo 2: indirect call via a function pointer.
    ldr     r1, =add_one    @ assembler ORs the Thumb bit in for us
    blx     r1              @ BLX uses BX semantics + sets LR
    @ r0 now holds 9
loop:
    b       loop

    .thumb_func
add_one:
    adds    r0, r0, #1
    bx      lr              @ PC = LR & ~1, stays in Thumb because LR[0] == 1
```

**Walkthrough:**

1. First `bl add_one` puts the return address (with Thumb bit set) in `LR`.
2. `bx lr` inside `add_one` reads `LR`, masks bit 0 off to form the PC, and uses bit 0 to confirm Thumb state — return.
3. `ldr r1, =add_one` — the `=symbol` form makes the assembler emit the value the linker fixes up, *with* bit 0 already set.
4. `blx r1` — calls through the register. If you'd hand-built `r1` with `ldr r1, =add_one` then `bics r1, #1`, this `blx`/`bx` would fault.

### Example 2 — tail-jump through a register

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    movs    r0, #5
    ldr     r2, =plus_one
    bx      r2              @ tail-jump; LR is whatever the caller set
    @ never reached: plus_one's bx lr returns to caller of reset_handler
loop:
    b       loop

    .thumb_func
plus_one:
    adds    r0, r0, #1
    bx      lr
```

**Walkthrough:**

1. `ldr r2, =plus_one` — Thumb bit set by the `.thumb_func` directive.
2. `bx r2` — jump (no link) to `plus_one`. `LR` is unchanged, so when `plus_one` returns it returns to *our* caller — the textbook tail-call pattern compilers use to save a stack frame.
3. `bx lr` inside `plus_one` reads the unchanged `LR`, masks bit 0 to form the PC, and returns. Note that `loop` is never reached in this contrived setup — `bx r2` already left.

## See also

- [BL](BL.md) — direct PC-relative call (literal label).
- [BLX](BLX.md) — call via register; same Thumb-bit rule.
- [B](B.md) — plain PC-relative branch.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.20 — *BX*.
