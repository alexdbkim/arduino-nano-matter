# SMLAD — Dual signed 16×16 multiply, then add the two products and accumulate into a 32-bit register.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLAD <Rd>, <Rn>, <Rm>, <Ra>
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
p1 = SInt(Rn[15:0])  * SInt(Rm[15:0])
p2 = SInt(Rn[31:16]) * SInt(Rm[31:16])
sum32 = p1 + p2          // no overflow possible at this step
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
| T1 | 32-bit | `SMLAD` Rd, Rn, Rm, Ra |

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
    @ SMLAD demo: 2-tap FIR filter step
    @ R1 holds two Q15 samples [s1:s0], R2 holds two Q15 coefficients [c1:c0]
    @ R0 accumulates the running sum.
    movs    r0, #0
    ldr     r1, =0x40005000     @ s1=0x4000, s0=0x5000
    ldr     r2, =0x20003000     @ c1=0x2000, c0=0x3000
    smlad   r0, r1, r2, r0      @ r0 += s0*c0 + s1*c1
loop:
    b   loop
```

**Walkthrough:**

1. `movs r0, #0` — clear the FIR accumulator.
2. `ldr r1, =…` / `ldr r2, =…` — pack two Q15 samples and two Q15 coefficients into 32-bit lanes (top half = index 1, bottom half = index 0).
3. `smlad r0, r1, r2, r0` — one cycle does **both** taps: `r0 += s0·c0 + s1·c1`. This is the heart of any FIR/dot-product loop on Cortex-M.

## See also

- [SMLADX](SMLADX.md) — dual MAC, exchanged second operand
- [SMLSD](SMLSD.md) — dual multiply-subtract with accumulate
- [SMLSDX](SMLSDX.md) — dual multiply-subtract, exchanged
- [SMUAD](SMUAD.md) — same dual sum without accumulator
- [SMUADX](SMUADX.md) — exchanged dual sum, no accumulator
- [SMUSD](SMUSD.md) — dual difference, no accumulator
- [SMUSDX](SMUSDX.md) — exchanged dual difference, no accumulator
- [SMLALD](SMLALD.md) — 64-bit accumulator version
- [PKHBT](PKHBT.md) — pack two halfwords into the lane layout these instructions consume

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLAD*.
