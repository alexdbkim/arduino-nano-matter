# ASR — arithmetic shift right (signed divide by powers of two)

## Class & availability

- **Class:** Shift/Rotate
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
ASR{S}{<cond>} {<Rd>,} <Rm>, #<imm>           @ immediate form, imm = 1..32
ASR{S}{<cond>} {<Rd>,} <Rn>, <Rs>             @ register form
```

Right-shift `Rm`/`Rn` by N bits, **replicating bit 31** (the sign bit) into the vacated high bits. The last bit shifted out lands in C with `S`.

**When you'd actually use this** is **signed division by a power of two** — `asr r0, r0, #3` is `r0 / 8` for signed integers, which `LSR` would get wrong for negatives (it would zero-fill the sign bit and turn `-8` into a huge positive number). It's also the second half of fixed-point Q15.16 math: after a `SMULL` produces a 64-bit signed product, an `ASR` rescales the result back. Note that `ASR` rounds toward `-∞`, not toward zero — `(-1) >> 1 == -1`, not `0` — which is occasionally surprising but is exactly what compilers count on.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR; R0–R7 (T1) |
| `<Rm>` / `<Rn>` | source register | R0–R12, LR; R0–R7 (T1) |
| `<Rs>` | shift-amount register | only low 8 bits used |
| `#<imm>` | shift amount | 1..32 (`ASR #32` makes every bit equal to old bit 31; result is 0 or −1) |

## Operation (pseudocode)

```text
if ConditionPassed() then
    n = (immediate form) ? imm : UInt(R[s]<7:0>)
    (result, carry) = ASR_C(R[m], n)        @ shift right, sign-extend
    R[d] = result
    if S == '1' then
        APSR.N = result<31>                 @ same as old bit 31
        APSR.Z = IsZeroBit(result)
        APSR.C = carry
        @ APSR.V unchanged
```

Register form: `Rs<7:0> == 0` ⇒ C unchanged. `Rs >= 32` ⇒ result is `0` if old bit 31 = 0 else `0xFFFFFFFF`; C = old bit 31.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | – | – |

`ASRS` only. N keeps the sign of the input, since bit 31 is preserved.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `ASRS <Rd>, <Rm>, #<imm5>` — immediate, low registers |
| T2 | 16-bit | `ASRS <Rdn>, <Rm>` — register, low registers |
| T2 | 32-bit | `ASR{S}.W <Rd>, <Rm>, #<imm>` — immediate |
| T2 | 32-bit | `ASR{S}.W <Rd>, <Rn>, <Rs>` — register |

## Exceptions / faults

- (none).

## Example

### Example 1 — signed shift basics

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ ASR demo: signed divide-by-2 and signed field extract.
    ldr     r0, =0xFFFFFFF0        @ -16 in two's complement
    asr     r1, r0, #1             @ r1 = 0xFFFFFFF8 = -8 (signed /2)
    asr     r2, r0, #4             @ r2 = 0xFFFFFFFF = -1
    mov     r3, #2
    asrs    r4, r0, r3             @ register form: r4 = -4, N=1, Z=0, C=0
loop:
    b   loop
```

**Walkthrough:**

1. `asr r1, r0, #1` — signed `/2`. Compare with `lsr r1, r0, #1` which would have produced `0x7FFFFFF8` — totally wrong for a negative value.
2. `asr r2, r0, #4` — `-16 >> 4 = -1`. Sign extension fills the top.
3. `asrs r4, r0, r3` — register-form variant. `S` is on, so N reflects the (preserved) sign and you can branch on it.

This is the part that bites people: ARM's `ASR` rounds **toward minus infinity** for negative inputs, not toward zero. `(-1) ASR 1 = -1`, not `0`. C compilers know this and emit corrections when language semantics demand truncation.

### Example 2 — Q15.16 fixed-point multiply

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Multiply two Q15.16 fixed-point numbers; rescale result back to Q15.16.
    ldr     r0, =0x00018000        @ 1.5 in Q15.16
    ldr     r1, =0x00028000        @ 2.5 in Q15.16
    smull   r2, r3, r0, r1         @ r3:r2 = signed 64-bit product (Q30.32)
    lsr     r2, r2, #16            @ shift the low half right by 16
    orr     r2, r2, r3, lsl #16    @ r2 = product in Q15.16 = 0x0003C000 (3.75)
    asr     r3, r3, #16            @ r3 = sign-extended overflow word (0 or -1 if in range)
loop:
    b   loop
```

**Walkthrough:** `SMULL` produces a 64-bit signed product in `r3:r2`; the Q15.16 result lives in bits [47:16] of that pair. The `LSR`+`ORR` recombines those bits into `r2`, and the final `ASR r3, r3, #16` sign-extends the high word so a non-trivial value there flags overflow. Plain `LSR` on `r3` instead would silently lose the sign of negative results.

## See also

- [LSR](LSR.md) — unsigned right shift (zero fill). Pick `LSR` for `unsigned`, `ASR` for `int`.
- [LSL](LSL.md), [ROR](ROR.md), [RRX](RRX.md) — the rest of the shifter family.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.13 — *ASR (immediate)* and §C2.4.14 — *ASR (register)*.
