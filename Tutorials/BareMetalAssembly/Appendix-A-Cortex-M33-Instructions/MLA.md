# MLA — multiply-accumulate: `Rd = Ra + (Rn × Rm)`

## Class & availability

- **Class:** Multiply (arithmetic)
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
MLA{<cond>} <Rd>, <Rn>, <Rm>, <Ra>
```

Low 32 bits of `Ra + Rn*Rm`. Four register operands, all distinct in the encoding (though they can be the same physical register).

**When you'd actually use this**: MLA fuses `acc += a*b` into one cycle, so it's the natural hot-loop instruction for FIR filters, IIR biquads, dot products, Horner-form polynomial evaluation, and bilinear interpolation in graphics. Without it you'd pay two instructions (`MUL` + `ADD`) per tap *and* burn an extra register — over a 32-tap filter that's a real cycle budget. There is no `MLAS`, so if you need flags afterwards do a `cmp Rd, #0`. Use plain MUL for the very first tap when the accumulator hasn't been initialised yet — accumulating into garbage is the easy way to get "random" filter output.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | `R0`–`R12` |
| `<Rn>` | first factor | `R0`–`R12` |
| `<Rm>` | second factor | `R0`–`R12` |
| `<Ra>` | accumulator (added to product) | `R0`–`R12` |

`PC`, `SP`, and `LR` are not allowed as any operand. There is **no flag-setting form**.

## Operation (pseudocode)

```text
if ConditionPassed() then
    operand1 = SInt(R[n])
    operand2 = SInt(R[m])
    addend   = SInt(R[a])
    result   = addend + operand1 * operand2
    R[d] = result<31:0>
```

Sign of the inputs doesn't matter for the low 32 bits.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never. There is no `MLAS`. If you need flags, follow with `cmp Rd, #0` or similar.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `MLA Rd, Rn, Rm, Ra` (32-bit only — no 16-bit encoding) |

## Exceptions / faults

- (none).

## Example

### Example 1 — 2-element dot product

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ MLA demo: dot product of two 2-element vectors
    @ result = a0*b0 + a1*b1
    movs    r0, #3              @ a0
    movs    r1, #4              @ b0
    movs    r2, #5              @ a1
    movs    r3, #6              @ b1
    mul     r4, r0, r1          @ r4 = a0*b0 = 12
    mla     r4, r2, r3, r4      @ r4 = a1*b1 + r4 = 30 + 12 = 42
loop:
    b       loop
```

**Walkthrough:**

1. `mul r4, r0, r1` — start the running sum with the first product.
2. `mla r4, r2, r3, r4` — fuses "multiply and add" into one cycle: compute `r2*r3`, add it to `r4`, store back into `r4`. This is the bread and butter of FIR filters and DSP loops.

### Example 2 — 3-tap unrolled FIR-style accumulator

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global reset_handler
    .thumb_func
reset_handler:
    movs    r0, #10             @ sample s0
    movs    r1, #2              @ tap c0
    mul     r4, r0, r1          @ acc = s0*c0 = 20  (first tap uses MUL)
    movs    r0, #20             @ s1
    movs    r1, #3              @ c1
    mla     r4, r0, r1, r4      @ acc += s1*c1 -> 80
    movs    r0, #30             @ s2
    movs    r1, #4              @ c2
    mla     r4, r0, r1, r4      @ acc += s2*c2 -> 200
loop:
    b       loop
```

**Walkthrough:**

1. The first tap uses plain `MUL` because the accumulator hasn't been initialised yet — using `MLA` here would add into garbage.
2. Each subsequent tap is a single `MLA` cycle: multiply, add, store back into the same register. This is the inner-loop shape used by every textbook FIR on Cortex-M.
3. There is no flag-setting variant, so loops typically use a separate `subs` on the index register to decide when to stop.

## See also

- [MUL](MUL.md) — the multiply on its own
- [MLS](MLS.md) — the subtractive form, `Rd = Ra − Rn*Rm`
- [SMLAL](SMLAL.md) / [UMLAL](UMLAL.md) — 64-bit accumulating multiply

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.99 — *MLA*.
