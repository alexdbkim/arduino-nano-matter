# IT — If-Then: gate up to four following instructions on a condition

## Class & availability

- **Class:** Branch (control flow without branching)
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
IT{x{y{z}}}   <firstcond>
```

**When you'd actually use this**: `IT` lets you make 1–4 instructions conditional without the cost of a real branch — no pipeline-flush penalty, no extra label, denser code. The classic use cases are tiny ternaries (`r0 = (cond) ? a : b`), branchless absolute value, and saturating clamps. Without `IT` you'd write `Bcc skip; …; skip:`, which costs at least one branch instruction plus the not-taken pipeline behaviour. The thing that bites: the suffix has to *exactly* match the number of instructions in the block (`ITTE` = three instructions, no labels inside, no `B`/`BL`/`CBZ`/`IT`), and most instructions inside an `IT` block do **not** update flags — easy to forget and end up debugging "why is this `cmp` not setting `Z`?"

`IT` introduces an *IT block* of one to four instructions that execute conditionally without an actual branch. The mnemonic suffix encodes the conditions of the following instructions:

| Mnemonic | Block | Conditions of insns 1–4 |
|----------|-------|-------------------------|
| `IT cond`     | 1 insn  | T |
| `ITT cond`    | 2 insns | T, T |
| `ITE cond`    | 2 insns | T, E |
| `ITTT cond`   | 3 insns | T, T, T |
| `ITTE cond`   | 3 insns | T, T, E |
| `ITET cond`   | 3 insns | T, E, T |
| `ITEE cond`   | 3 insns | T, E, E |
| `ITTTT cond`  | 4 insns | T, T, T, T |
| `ITTTE cond`  | 4 insns | T, T, T, E |
| `ITTET cond`  | 4 insns | T, T, E, T |
| `ITTEE cond`  | 4 insns | T, T, E, E |
| `ITETT cond`  | 4 insns | T, E, T, T |
| `ITETE cond`  | 4 insns | T, E, T, E |
| `ITEET cond`  | 4 insns | T, E, E, T |
| `ITEEE cond`  | 4 insns | T, E, E, E |

`T` ("then") = same as `<firstcond>`; `E` ("else") = the inverted condition. **Every** instruction inside the block must carry the matching condition suffix; the assembler enforces it.

Why use it: avoids a branch (no pipeline-flush penalty for the not-taken path on Cortex-M33), keeps code dense, and lets you write small selects (`r0 = (cond) ? a : b`) in a couple of instructions.

This is the part that bites people:

- The block must contain exactly the number of instructions implied by the suffix. No more, no less. No labels inside the block. No `B`/`BL`/`BX`/`CBZ`/`IT` inside the block (with narrow exceptions — see the ARM ARM, generally avoid).
- Instructions inside an IT block do **not** update the flags (with the very specific exception that a `CMP`/`CMN`/`TST`/`TEQ` always updates flags, and `S`-suffixed insns inside an IT block follow the rule in the ARM ARM — keep it simple: don't rely on flag updates from inside an IT block).
- Falling off the end of an IT block by jumping out of it is `UNPREDICTABLE`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<firstcond>` | condition code | any of the standard ones except `AL` for blocks with `E` suffix |

## Operation (pseudocode)

```text
ITSTATE.cond_base = encoded(firstcond)
ITSTATE.mask      = encoded(T/E pattern)
// for each of the next N instructions:
//   if ITSTATE.bit indicates T: condition = firstcond
//   else                       : condition = invert(firstcond)
//   if !ConditionPassed(condition) then NOP this instruction
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

`IT` itself only updates the internal `ITSTATE` field of `EPSR`.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `IT{x{y{z}}} <firstcond>` — only encoding |

## Exceptions / faults

- (none from `IT` itself; malformed blocks are rejected by the assembler)

## Example

### Example 1 — branchless absolute value + equality select

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ IT demo: branchless absolute value of r0 (signed).
    movs    r0, #-5
    cmp     r0, #0
    it      mi              @ "if minus, then..."
    rsbmi   r0, r0, #0      @ r0 = 0 - r0  (executed only when N == 1)
    @ r0 == 5

    @ ITE demo: r1 = (r2 == r3) ? 1 : 0
    movs    r2, #4
    movs    r3, #4
    cmp     r2, r3
    ite     eq              @ "if equal, then ... else ..."
    moveq   r1, #1          @ runs only when Z == 1
    movne   r1, #0          @ runs only when Z == 0
loop:
    b       loop
```

**Walkthrough:**

1. `cmp r0, #0` — sets `N` = 1 because `r0` is negative.
2. `it mi` — opens a 1-instruction block whose condition is "minus" (N == 1).
3. `rsbmi r0, r0, #0` — executes because `MI` holds; computes `0 − r0` = +5. With a non-negative input the instruction is silently skipped.
4. `cmp r2, r3` — sets `Z` per equality.
5. `ite eq` — opens a 2-instruction block: first instruction runs on `EQ`, second on the inverse (`NE`).
6. `moveq r1, #1` / `movne r1, #0` — exactly one of these takes effect, giving a branchless select.

### Example 2 — set a flag iff non-zero

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    movs    r0, #0          @ default flag = 0
    movs    r1, #5          @ value to test
    cmp     r1, #0
    it      ne              @ 1-instruction "then" block, condition NE
    movne   r0, #1          @ runs only when r1 != 0
loop:
    b       loop
```

**Walkthrough:**

1. `movs r0, #0` — pre-seed the result to "false". `IT` only conditionally executes one arm; the default has to be set before the block.
2. `cmp r1, #0` — sets `Z` based on whether `r1` is zero.
3. `it ne` — opens a single-instruction block with condition NE (Z == 0).
4. `movne r0, #1` — runs only when `Z == 0`. The condition suffix is mandatory and must match the IT mask.
5. Net effect: `r0 = (r1 != 0) ? 1 : 0`, branchless, four halfwords total.

## See also

- [B](B.md) — alternative when you need to gate more than four instructions or include a branch.
- [CBZ](CBZ.md) / [CBNZ](CBNZ.md) — flag-free zero tests.
- [BL](BL.md) — wrap in `IT` to make a call conditional.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.46 — *IT*.
