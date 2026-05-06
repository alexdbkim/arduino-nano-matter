# MOVS — copy a register or immediate AND update N/Z (and sometimes C)

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
MOVS  <Rd>, <Rm>          @ register form  — sets N, Z (C from shifter if T3)
MOVS  <Rd>, #<imm>        @ immediate form — sets N, Z, and possibly C
```

**When you'd actually use this** is when a copy doubles as a compare-with-zero. `MOVS rN, rM` updates N and Z, so it's the canonical way to kick off a chain of conditional code (`beq`, `bmi`, etc.) without an explicit `CMP`. Compilers emit it for assignments where the result is immediately tested, and for early loop-init where the freshly written value's sign or zeroness matters. Stay with plain `MOV` (no `S`) inside an `IT` block or when you've already set the flags upstream and want to keep them.

`MOVS` is the flag-setting sibling of [`MOV`](MOV.md). Same data path, different `S` bit in the encoding.

## Operands

| Field   | Type                 | Constraints                                                  |
|---------|----------------------|--------------------------------------------------------------|
| `<Rd>`  | destination register | R0–R7 in T1; R0–R14 in T2/T3. PC not allowed with `S`.       |
| `<Rm>`  | source register      | R0–R14 (T2 forbids R13/R15).                                 |
| `<imm>` | immediate            | T1: 0–255 (8-bit). T2 (32-bit): modified immediate.          |

## Operation (pseudocode)

```text
if ConditionPassed() then
    (result, carry) = decode_operand();      @ carry from imm/shifter or unchanged
    R[d] = result;
    APSR.N = result<31>;
    APSR.Z = IsZeroBit(result);
    APSR.C = carry;                          @ if encoding produces one; else unchanged
    @ APSR.V is unchanged.
```

## Flags affected

| N | Z | C       | V | Q |
|---|---|---------|---|---|
| ✓ | ✓ | ✓ (some)| – | – |

N and Z always update. C updates only when the encoding's modified-immediate carries a `C` bit, or when a shifted-register form (T3) produces a shifter carry-out. V and Q never change.

## Encodings

| Variant | Width  | Form                                                                 |
|---------|--------|----------------------------------------------------------------------|
| T1      | 16-bit | `MOVS <Rd>, #<imm8>` — outside an `IT` block.                        |
| T2      | 16-bit | `MOVS <Rd>, <Rm>` — encoded as `LSLS <Rd>, <Rm>, #0` (low regs only).|
| T2 (32) | 32-bit | `MOVS.W <Rd>, #<modified_imm12>`.                                    |
| T3 (32) | 32-bit | `MOVS.W <Rd>, <Rm>{, <shift>}` — shifted-register, sets C from shifter. |

This is the part that bites people: 16-bit `MOVS Rd, Rm` *must* sit outside an `IT` block. Inside `IT`, use the un-suffixed `MOV` so flags are not clobbered.

## Exceptions / faults

- (none).

## Example

### Example 1 — Move and inspect Z flag

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ MOVS demo: setting flags as a side effect of a move.
    movs    r0, #0                  @ Z=1, N=0 — clean way to set Z
    movs    r1, #0xFF               @ N=0, Z=0
    movs    r2, r1                  @ copies and refreshes N/Z from r1
    movs    r3, #0x80000000         @ N=1, Z=0 (32-bit modified imm)
    beq     never_taken             @ uses the Z flag MOVS just set
never_taken:
loop:
    b   loop
```

**Walkthrough:**

1. `movs r0, #0` — writes 0 to R0 and sets Z=1, N=0. A common idiom for "zero a register and set Z".
2. `movs r1, #0xFF` — sets R1 = 255, clears Z, clears N.
3. `movs r2, r1` — copies R1 to R2 and refreshes N/Z from the value.
4. `movs r3, #0x80000000` — uses the 32-bit modified-immediate; N becomes 1.
5. `beq never_taken` — branches on the Z flag the previous `movs` left behind, illustrating that `MOVS` is genuinely a compare-with-zero in disguise.

### Example 2 — Counter init and zero-check fall-through

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    movs    r0, #4              @ counter = 4 (and Z=0)
1:  subs    r0, r0, #1          @ flags from each subtract
    bne     1b                  @ uses Z that subs produced
    movs    r1, #0              @ Z=1 — gates the next branch
    beq     done                @ taken because movs just set Z
done:
loop:
    b   loop
```

**Walkthrough:**

1. `movs r0, #4` — initialise the loop counter and clear Z in one go.
2. `subs/bne` — the loop body iterates four times until `r0` reaches 0.
3. `movs r1, #0` — drops a zero into r1 *and* sets Z=1, so the immediate `beq` is taken without an explicit `cmp`.
4. This is exactly the pattern the compiler emits for `if (!(x = 0)) ...`-style assignments-as-conditions.

## See also

- [MOV](MOV.md) — same data path, no flag update.
- [MVN](MVN.md) — has its own `MVNS` flag-setting form.
- [CMP](CMP.md) — explicit compare-with-zero/immediate that only updates flags.
- [LDR](LDR.md) — load that does **not** set flags (despite reading memory).

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.69 — *MOV (immediate)* / *MOV (register)*, with `S = 1`.
