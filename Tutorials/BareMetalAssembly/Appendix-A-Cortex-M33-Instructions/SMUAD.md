# SMUAD — Dual signed 16×16 multiply, then add the two products into a 32-bit register.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMUAD <Rd>, <Rn>, <Rm>
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | R0–R12, LR; not PC/SP |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |

## Operation (pseudocode)

```text
p1 = SInt(Rn[15:0])  * SInt(Rm[15:0])
p2 = SInt(Rn[31:16]) * SInt(Rm[31:16])
result = p1 + p2
Rd = result[31:0]
if SignedOverflow32(result) then APSR.Q = 1   // SUAD/SUSD only
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | ✓ |

Sets `Q` on signed overflow of the accumulate or dual-sum step. `N`, `Z`, `C`, `V` are never touched.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMUAD` Rd, Rn, Rm |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMUAD demo: 2-element dot product, no accumulator
    ldr     r1, =0x00050003     @ [5, 3]
    ldr     r2, =0x00070002     @ [7, 2]
    smuad   r0, r1, r2          @ r0 = 3*2 + 5*7 = 41
loop:
    b   loop
```

**Walkthrough:**

1. Load two pairs of Q15 (or any int16) values.
2. `smuad` returns the dot product of the pair in one cycle — handy for inner kernels that don't carry an accumulator across iterations.
3. If the dual sum overflows 32 bits (only possible when both products are `0x40000000` of the same sign), `Q` sticks.

## See also

- [SMLAD](SMLAD.md) — dual MAC, non-exchanged, accumulate
- [SMLADX](SMLADX.md) — dual MAC, exchanged second operand
- [SMLSD](SMLSD.md) — dual multiply-subtract with accumulate
- [SMLSDX](SMLSDX.md) — dual multiply-subtract, exchanged
- [SMUADX](SMUADX.md) — exchanged dual sum, no accumulator
- [SMUSD](SMUSD.md) — dual difference, no accumulator
- [SMUSDX](SMUSDX.md) — exchanged dual difference, no accumulator
- [SMLALD](SMLALD.md) — 64-bit accumulator version
- [PKHBT](PKHBT.md) — pack two halfwords into the lane layout these instructions consume

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMUAD*.
