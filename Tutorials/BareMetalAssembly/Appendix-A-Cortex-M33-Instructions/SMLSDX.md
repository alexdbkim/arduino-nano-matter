# SMLSDX — Dual signed 16×16 multiply, then subtract the two products (with halves of the second operand exchanged) and accumulate into a 32-bit register.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLSDX <Rd>, <Rn>, <Rm>, <Ra>
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | R0–R12, LR; not PC/SP |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |
| `<Ra>` | accumulator GPR | R0–R12, LR |

## Operation (pseudocode)

```text
p1 = SInt(Rn[15:0])  * SInt(Rm[31:16])
p2 = SInt(Rn[31:16]) * SInt(Rm[15:0])
sum32 = p1 - p2          // no overflow possible at this step
result = sum32 + SInt(Ra)       // 33-bit signed add
Rd = result[31:0]
if SignedOverflow(sum32, Ra) then APSR.Q = 1
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | ✓ |

Sets `Q` on signed overflow of the accumulate or dual-sum step. `N`, `Z`, `C`, `V` are never touched.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMLSDX` Rd, Rn, Rm, Ra |

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
    @ SMLSDX demo: cross-difference for complex-conjugate dot product
    movs    r0, #0
    ldr     r1, =0x00020001
    ldr     r2, =0x00040003
    smlsdx  r0, r1, r2, r0      @ r0 += a*d - b*c
loop:
    b   loop
```

**Walkthrough:**

1. Same packing as SMLSD, but the second operand's halves are swapped before the multiplies.
2. Result: `Rn[lo]*Rm[hi] - Rn[hi]*Rm[lo]` — appears in conjugate complex products and DCT butterflies.

## See also

- [SMLAD](SMLAD.md) — dual MAC, non-exchanged, accumulate
- [SMLADX](SMLADX.md) — dual MAC, exchanged second operand
- [SMLSD](SMLSD.md) — dual multiply-subtract with accumulate
- [SMUAD](SMUAD.md) — same dual sum without accumulator
- [SMUADX](SMUADX.md) — exchanged dual sum, no accumulator
- [SMUSD](SMUSD.md) — dual difference, no accumulator
- [SMUSDX](SMUSDX.md) — exchanged dual difference, no accumulator
- [SMLALD](SMLALD.md) — 64-bit accumulator version
- [PKHBT](PKHBT.md) — pack two halfwords into the lane layout these instructions consume

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLSDX*.
