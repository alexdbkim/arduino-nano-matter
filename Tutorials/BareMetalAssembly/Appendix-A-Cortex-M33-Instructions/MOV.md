# MOV — copy a register or small immediate into a register

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
MOV{<cond>}   <Rd>, <Rm>            @ register form
MOV{<cond>}   <Rd>, #<imm>          @ immediate form (modified-imm or 16-bit)
```

`MOV` does **not** set flags. Use [`MOVS`](MOVS.md) for the flag-setting variant.

## Operands

| Field    | Type                 | Constraints                                                              |
|----------|----------------------|--------------------------------------------------------------------------|
| `<Rd>`   | destination register | R0–R15. PC writes are an interworking branch.                            |
| `<Rm>`   | source register      | R0–R15.                                                                  |
| `<imm>`  | immediate            | T1: 0–255. T2: any 16-bit value (uses [`MOVW`](MOVW.md) encoding).       |
| T3 imm   | modified immediate   | 12-bit ARM "thumb-expanded" constant (rotated/replicated 8-bit pattern). |

## Operation (pseudocode)

```text
if ConditionPassed() then
    result = (immediate form) ? imm32 : R[m];
    if d == 15 then
        ALUWritePC(result);          @ interworking branch
    else
        R[d] = result;
    @ Flags unchanged (no S suffix on MOV).
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

`MOV` never updates flags. The flag-setting form is `MOVS`.

## Encodings

| Variant | Width  | Form                                                              |
|---------|--------|-------------------------------------------------------------------|
| T1      | 16-bit | `MOV <Rd>, <Rm>` — high/low register move (any R0–R15).           |
| T2      | 16-bit | `MOVS <Rd>, #<imm8>` — flag-setting only; outside Thumb IT block. |
| T1 (32) | 32-bit | `MOV{S}.W <Rd>, #<modified_imm12>` — encoded constant.            |
| T2 (32) | 32-bit | `MOVW <Rd>, #<imm16>` — full 16-bit literal (see [`MOVW`](MOVW.md)). |
| T3 (32) | 32-bit | `MOV{S}.W <Rd>, <Rm>{, <shift>}` — shifted-register form.         |

## Exceptions / faults

- (none) — purely register/immediate.
- Writing PC produces an interworking branch; an unaligned target raises **UsageFault (INVSTATE)**.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ MOV demo: load constants and copy registers without touching flags.
    mov     r0, #42                 @ small immediate, T1 encoding
    mov     r1, r0                  @ register-to-register copy
    mov.w   r2, #0x00FF00FF         @ modified immediate (replicated byte)
    movw    r3, #0xBEEF             @ full 16-bit literal via MOVW
    movt    r3, #0xDEAD             @ top half via MOVT -> r3 = 0xDEADBEEF
loop:
    b   loop
```

**Walkthrough:**

1. `mov r0, #42` — places the literal 42 in R0; flags untouched.
2. `mov r1, r0` — copies R0 into R1; the assembler picks the 16-bit T1 encoding.
3. `mov.w r2, #0x00FF00FF` — uses the 32-bit modified-immediate encoding (replicated byte pattern).
4. `movw r3, #0xBEEF` then `movt r3, #0xDEAD` — the canonical way to get an arbitrary 32-bit constant into a register without a literal pool. This is the part that bites people: a single `MOV` cannot hold any 32-bit value, only ones the modified-immediate scheme can encode.

## See also

- [MOVS](MOVS.md) — same op but updates N/Z (and sometimes C).
- [MOVW](MOVW.md) — load any 16-bit value into the bottom half.
- [MOVT](MOVT.md) — load any 16-bit value into the top half (pairs with MOVW).
- [MVN](MVN.md) — move bitwise NOT of operand.
- [LDR](LDR.md) — for constants that don't fit, use a PC-relative literal pool.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.69 — *MOV (immediate)* and *MOV (register)*.
