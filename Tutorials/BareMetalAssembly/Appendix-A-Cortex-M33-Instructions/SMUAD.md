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

**When you'd actually use this** — a single-shot 2-element Q15 dot product (no accumulator). Most useful as the *first* iteration of a manual reduction (set `r0` with SMUAD, then keep accumulating with SMLAD), and for `|x|² = re² + im²` of a complex sample packed `[im:re]`: `SMUAD r0, r1, r1` produces magnitude-squared in one cycle. Without it, magnitude-squared takes two `SMUL*` plus an `ADD` (≈3× cycles); on M0+ with no DSP it's 4–5×.

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

### Example 1 — 2-element dot product, no accumulator

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

### Example 2 — Magnitude-squared of a complex Q15 sample in one instruction

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ |x|^2 = re^2 + im^2 of a complex sample packed [im:re].
    @ SMUAD r0, r1, r1 squares each lane and sums them in one cycle.
    ldr     r1, =0x00040003     @ x = 3 + 4j  (re=3, im=4)
    smuad   r0, r1, r1          @ r0 = 3*3 + 4*4 = 25
    ldr     r1, =0xFFFB0005     @ x = 5 - 5j  (re=5, im=-5 sign-extended)
    smuad   r2, r1, r1          @ r2 = 5*5 + (-5)*(-5) = 50
loop:
    b   loop
```

**Walkthrough:**

1. With `Rn = Rm`, SMUAD produces `re·re + im·im` — a one-cycle complex magnitude-squared, independent of how the lanes are interpreted as Q15 or plain int16.
2. This is the per-sample work of an FFT power spectrum (`|X[k]|²`) or RSSI estimator — the core of every BLE / Wi-Fi receiver running on the EFR32MG24.
3. Without SMUAD: `SMULBB r2, r1, r1; SMULTT r3, r1, r1; ADD r0, r2, r3` — 3 instructions, 3+ cycles, instead of 1.

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
