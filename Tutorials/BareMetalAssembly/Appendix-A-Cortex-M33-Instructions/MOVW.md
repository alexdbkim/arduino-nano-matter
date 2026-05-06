# MOVW — load an arbitrary 16-bit immediate into the bottom half of a register

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
MOVW  <Rd>, #<imm16>
```

**When you'd actually use this** is the first half of a `MOVW`/`MOVT` pair to materialise an arbitrary 32-bit constant in two instructions, no literal pool needed. Hand-written boot code uses it for peripheral base addresses, vector-table pointers, and other absolute MMIO targets. Compilers on M-profile prefer it over `LDR Rd, =const` whenever the constant is known at link time, because it avoids the indirect memory load and the literal-pool word — the result is faster and produces a smaller, more predictable instruction stream.

Writes `imm16` to bits [15:0] of `<Rd>` and **zero-extends** bits [31:16]. Pair with [`MOVT`](MOVT.md) to load any 32-bit constant in two instructions.

## Operands

| Field    | Type                 | Constraints                                |
|----------|----------------------|--------------------------------------------|
| `<Rd>`   | destination register | R0–R12, R14 (LR). SP and PC are forbidden. |
| `<imm>`  | immediate            | 0..65535 (16-bit unsigned).                |

The assembler also accepts `MOV <Rd>, #<imm16>` and silently emits `MOVW` when needed; writing `MOVW` makes intent explicit.

## Operation (pseudocode)

```text
if ConditionPassed() then
    R[d]<15:0>  = imm16;
    R[d]<31:16> = 0;          @ top half is *cleared*, not preserved
    @ Flags unchanged.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags (no `S` form).

## Encodings

| Variant | Width  | Form                                                       |
|---------|--------|------------------------------------------------------------|
| T3      | 32-bit | `MOVW <Rd>, #<imm16>` — only encoding; no 16-bit form.     |

## Exceptions / faults

- (none).

## Example

### Example 1 — Build an MMIO address with MOVW/MOVT

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ MOVW/MOVT demo: build a 32-bit MMIO address (GPIO_PORTA base on EFR32MG24).
    movw    r0, #0xA000             @ low half  -> r0 = 0x0000A000
    movt    r0, #0x5003             @ high half -> r0 = 0x5003A000
    movw    r1, #0xFFFF             @ r1 = 0x0000FFFF (top half cleared)
    @ Equivalent shorthand the assembler also accepts:
    mov     r2, #0x1234             @ assembled as MOVW r2, #0x1234
loop:
    b   loop
```

**Walkthrough:**

1. `movw r0, #0xA000` — writes 0x0000A000 to R0; the upper half is zeroed.
2. `movt r0, #0x5003` — overwrites *only* the top half, producing 0x5003A000.
3. `movw r1, #0xFFFF` — note R1 ends as 0x0000FFFF, **not** 0xFFFFFFFF; this is the part that bites people.
4. `mov r2, #0x1234` — the unified syntax lets you write `mov` and the assembler picks `MOVW` when the constant won't fit a modified immediate.

### Example 2 — Set up a SysTick CTRL pointer

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    movw    r0, #0xE010         @ low half of SysTick CTRL (0xE000E010)
    movt    r0, #0xE000         @ high half -> r0 = 0xE000E010
    movs    r1, #0x07           @ ENABLE | TICKINT | CLKSOURCE
    str     r1, [r0]            @ start SysTick
loop:
    b   loop
```

**Walkthrough:**

1. `movw r0, #0xE010` — bottom half of the SysTick CTRL register address.
2. `movt r0, #0xE000` — completes the address; `r0 = 0xE000E010`.
3. `str r1, [r0]` — kicks SysTick into running with interrupts at the processor clock.
4. The same two-instruction recipe scales to any 32-bit absolute MMIO address — perfect for early start-up code where literal pools haven't been laid out yet.

## See also

- [MOVT](MOVT.md) — companion that writes the *upper* half without disturbing the lower.
- [MOV](MOV.md) — overall move; assembler may pick MOVW for you.
- [LDR](LDR.md) — `LDR Rd, =const` uses a literal pool when MOVW/MOVT is undesirable.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.71 — *MOV (immediate)*, encoding T3 (`MOVW`).
