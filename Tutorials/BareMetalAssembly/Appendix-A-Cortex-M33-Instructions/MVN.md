# MVN — move bitwise NOT of an immediate or register into a register

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
MVN{S}{<cond>}  <Rd>, #<imm>
MVN{S}{<cond>}  <Rd>, <Rm>{, <shift>}
```

**When you'd actually use this** is when the constant you actually want is the bitwise complement of something simple. The compiler emits `MVN r0, #0` for `-1`, and `MVN r0, #0xF` for the mask `0xFFFFFFF0` — both are values that don't fit a single modified immediate but whose complement does. The alternative is a literal-pool load (`LDR r0, =0xFFFFFFF0`), which works for any value but costs a word in the pool plus an indirect access for a constant that `MVN` builds in one inline instruction.

Useful for materialising bit-masks like `0xFFFFFFF0` that don't fit cleanly as a modified immediate but whose complement does.

## Operands

| Field    | Type                 | Constraints                                                          |
|----------|----------------------|----------------------------------------------------------------------|
| `<Rd>`   | destination register | R0–R12, R14.                                                         |
| `<Rm>`   | source register      | R0–R12, R14.                                                         |
| `<imm>`  | immediate            | 12-bit modified immediate (with `S`, may also produce a carry).      |
| `<shift>`| shift specifier      | `LSL/LSR/ASR/ROR #n`, or `RRX` (T2 32-bit form only).                |

## Operation (pseudocode)

```text
if ConditionPassed() then
    (shifted, carry) = Shift_C(operand, shift_t, shift_n, APSR.C);
    result = NOT(shifted);
    R[d] = result;
    if S == '1' then
        APSR.N = result<31>;
        APSR.Z = IsZeroBit(result);
        APSR.C = carry;
        @ APSR.V unchanged.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | – | – |

Only with the `S` suffix (`MVNS`). N and Z reflect the result; C comes from the shifter / immediate carry. V is never touched.

## Encodings

| Variant | Width  | Form                                                              |
|---------|--------|-------------------------------------------------------------------|
| T1      | 16-bit | `MVNS <Rd>, <Rm>` — low registers (R0–R7), outside `IT`.          |
| T1 (32) | 32-bit | `MVN{S}.W <Rd>, #<modified_imm12>`.                               |
| T2 (32) | 32-bit | `MVN{S}.W <Rd>, <Rm>{, <shift>}`.                                 |

## Exceptions / faults

- (none).

## Example

### Example 1 — Build masks via complement

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ MVN demo: build masks via complement.
    mvn     r0, #0                  @ r0 = 0xFFFFFFFF (all ones)
    mvn     r1, #0x0F               @ r1 = 0xFFFFFFF0 (clear low nibble mask)
    movs    r2, #1
    mvn     r3, r2, lsl #4          @ r3 = NOT(1<<4) = 0xFFFFFFEF
    mvns    r4, #0x80000000         @ r4 = 0x7FFFFFFF; sets N=0, Z=0
loop:
    b   loop
```

**Walkthrough:**

1. `mvn r0, #0` — R0 = NOT(0) = 0xFFFFFFFF. The shortest path to "all ones".
2. `mvn r1, #0x0F` — R1 = 0xFFFFFFF0; handy for `BIC`/`AND`-style masks.
3. `mvn r3, r2, lsl #4` — shifts R2 left 4, then complements: a one-instruction "build-and-invert".
4. `mvns r4, #0x80000000` — flag-setting variant: writes 0x7FFFFFFF and updates N/Z (and C from the modified-immediate carry).

### Example 2 — Return -1 as an error sentinel

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    bl      try_op
loop:
    b   loop

    .thumb_func
try_op:
    mvn     r0, #0              @ r0 = 0xFFFFFFFF (== -1)
    bx      lr
```

**Walkthrough:**

1. `mvn r0, #0` — one 32-bit instruction, no literal pool. This is exactly what GCC emits for `return -1;` on Thumb-2.
2. `bx lr` — return; the caller compares `r0` against `-1` to detect failure.
3. The same pattern handles other inverse-of-small constants: `mvn r0, #0xFF` produces `0xFFFFFF00`, handy as a byte-clearing mask.

## See also

- [MOV](MOV.md) — plain move without complement.
- [BIC](BIC.md) — clears bits, often paired with masks built via `MVN`.
- [ORN](ORN.md) — OR with bitwise-NOT operand, same idea applied to OR.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.79 — *MVN (immediate)* / *MVN (register)*.
