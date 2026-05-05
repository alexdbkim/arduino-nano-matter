<!--
========================================================================
SHARED TEMPLATE — every instruction file in this folder MUST follow this
structure exactly, in this order, with these exact headings. Replace
{{...}} placeholders. Delete any rows / sections that are not applicable
ONLY by leaving them with the literal text "(none)" — never delete the
heading itself, so the structure stays scannable.

This file is documentation for contributors. It is NOT loaded by anything.
========================================================================
-->

# {{MNEMONIC}} — {{one-line plain-English summary}}

## Class & availability

- **Class:** {{Data movement | Arithmetic | Logical | Shift/Rotate | Compare | Branch | Bit manipulation | Saturation | Multiply | DSP-SIMD | Floating-point | System | Hint | Security}}
- **Architecture:** ARMv8-M Mainline {{(base) | + DSP | + FP | + Security}}
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** {{None | Privileged only}}
- **Secure-state required:** {{No | Yes (Security extension)}}

## Synopsis

```text
{{MNEMONIC}}{{S}}{{<cond>}} {{<Rd>,}} <Rn>, <operand2>
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | `R0`–`R12`, `LR`, `SP`, `PC` (varies; see Encodings) |
| `<Rn>` | source register | ... |
| `<operand2>` | flexible second operand | immediate / register / shifted register |

## Operation (pseudocode)

```text
if ConditionPassed() then
    {{instruction-specific behaviour}}
    if S == '1' then APSR.{N,Z,C,V} = ...
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| {{✓ \| –}} | {{✓ \| –}} | {{✓ \| –}} | {{✓ \| –}} | {{✓ \| –}} |

{{When set: only with the `S` suffix / always / never. One-sentence note.}}

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | {{operand restrictions}} |
| T2 | 32-bit | {{operand restrictions}} |

## Exceptions / faults

- {{e.g. UsageFault on unaligned access if CCR.UNALIGN_TRP=1, or "(none)"}}

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ {{MNEMONIC}} demo: {{one-line description}}
    {{actual instruction usage, 4–10 lines}}
loop:
    b   loop
```

**Walkthrough:**

1. `{{first instruction}}` — what it does and what it leaves in which register / flag.
2. `{{second instruction}}` — ...

## See also

- [{{RELATED1}}]({{RELATED1}}.md) — {{relationship in one phrase}}
- [{{RELATED2}}]({{RELATED2}}.md)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.{{xxx}}.
