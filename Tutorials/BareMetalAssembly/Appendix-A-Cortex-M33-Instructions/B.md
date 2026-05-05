# B — branch (optionally conditional) to a PC-relative label

## Class & availability

- **Class:** Branch
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
B{<cond>}   <label>
```

`<cond>` is one of: `EQ NE CS HS CC LO MI PL VS VC HI LS GE LT GT LE AL`.
`HS` is an alias for `CS`; `LO` is an alias for `CC`. `AL` (always) is the default and may be omitted.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<cond>` | condition code | tested against APSR `{N,Z,C,V}` before the branch is taken |
| `<label>` | PC-relative target | encoded as a signed immediate; ranges depend on encoding (see below) |

### Condition codes

| Code | Meaning | Flags tested |
|------|---------|--------------|
| `EQ` | equal | `Z == 1` |
| `NE` | not equal | `Z == 0` |
| `CS`/`HS` | carry set / unsigned higher-or-same | `C == 1` |
| `CC`/`LO` | carry clear / unsigned lower | `C == 0` |
| `MI` | minus / negative | `N == 1` |
| `PL` | plus / non-negative | `N == 0` |
| `VS` | overflow set | `V == 1` |
| `VC` | overflow clear | `V == 0` |
| `HI` | unsigned higher | `C == 1 && Z == 0` |
| `LS` | unsigned lower-or-same | `C == 0 \|\| Z == 1` |
| `GE` | signed greater-or-equal | `N == V` |
| `LT` | signed less-than | `N != V` |
| `GT` | signed greater-than | `Z == 0 && N == V` |
| `LE` | signed less-or-equal | `Z == 1 \|\| N != V` |
| `AL` | always (default) | — |

## Operation (pseudocode)

```text
if ConditionPassed(<cond>) then
    PC = PC + sign_extend(imm) + 4   // PC reads as current+4 in Thumb
```

`B` does not change `LR`. It is a plain jump, not a call.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

`B` never writes flags; it only reads them when a condition is supplied.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `B<cond> <label>`, range ±256 B; `cond != 1110/1111` |
| T2 | 16-bit | `B <label>` (unconditional), range ±2 KB |
| T3 | 32-bit | `B<cond>.W <label>`, range ±1 MB |
| T4 | 32-bit | `B.W <label>` (unconditional), range ±16 MB |

The assembler picks the narrowest encoding that reaches; force 32-bit with the `.W` suffix when you need the longer range.

## Exceptions / faults

- `UsageFault (INVSTATE)` if the branch is taken to an address whose bit 0 is 0 — but `B` always targets a Thumb label, so this only happens when the immediate has been cooked up incorrectly. (none under normal use)

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ B demo: count down r0 from 5 to 0 with a conditional branch
    movs    r0, #5
count_down:
    subs    r0, r0, #1      @ S-suffix updates Z flag
    bne     count_down      @ branch back while r0 != 0
    movs    r1, #0xAA       @ executed once r0 reaches zero
loop:
    b       loop
```

**Walkthrough:**

1. `movs r0, #5` — seeds the loop counter and (because of `S`) clears N/Z/C/V from the move.
2. `subs r0, r0, #1` — decrements and updates `Z` based on the new value of `r0`.
3. `bne count_down` — re-enters the loop while `Z == 0`; falls through when `r0` hit zero.
4. `movs r1, #0xAA` — runs exactly once, proving the conditional branch terminated.
5. `b loop` — unconditional branch (the parking spin you see in every example).

## See also

- [BL](BL.md) — same shape, but writes `LR`; used for function calls.
- [BX](BX.md) — branch to an address held in a register.
- [CBZ](CBZ.md) / [CBNZ](CBNZ.md) — compact compare-and-branch on zero.
- [IT](IT.md) — apply a condition to up to four following instructions instead of branching.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.15 — *B*.
