# SMLSD — Dual signed 16×16 multiply, then subtract the two products and accumulate into a 32-bit register.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLSD <Rd>, <Rn>, <Rm>, <Ra>
```

**When you'd actually use this** — the **real** part of a complex Q15 multiply, `Re((a+bi)(c+di)) = a·c − b·d`, falls out as one SMLSD with packing `[b:a]` × `[d:c]`. Pair it with SMLADX (`Im = a·d + b·c`) and you've done a full complex MAC in two instructions — the FFT-butterfly inner kernel. SMLSD is also the trailing stage of a Hilbert-transform mixer where you cross-multiply and subtract. Without it, every complex-multiply step needs two `SMUL*` plus an `SSUB` (≈3× the cycles).

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
| T1 | 32-bit | `SMLSD` Rd, Rn, Rm, Ra |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

## Example

### Example 1 — Real part of a single complex multiply

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMLSD demo: complex-number Re part of (a+bi)*(c+di) = (ac - bd) + (ad+bc)i
    @ R1 = [b:a] (imag:real of operand 1), R2 = [d:c] (imag:real of operand 2)
    movs    r0, #0
    ldr     r1, =0x00020001     @ a=1, b=2
    ldr     r2, =0x00040003     @ c=3, d=4
    smlsd   r0, r1, r2, r0      @ r0 += a*c - b*d = 1*3 - 2*4 = -5
loop:
    b   loop
```

**Walkthrough:**

1. Pack `(real, imag)` of each complex sample into the bottom/top halves of one register.
2. `smlsd` computes `Rn[lo]*Rm[lo] - Rn[hi]*Rm[hi]` and accumulates — exactly the real part of complex multiply.
3. Pair this with `SMLADX` to get the imaginary part `(ad + bc)` in the same loop.

### Example 2 — Hilbert-transform trailing mix-down stage (Re accumulator)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Real-axis output of a Hilbert mixer: Σ (x_re*h_re - x_im*h_im).
    @ Two complex samples, packed [im:re], dotted against two coefficients [im:re].
    movs    r0, #0
    ldr     r1, =0x00020001     @ x0 = 1 + 2j
    ldr     r2, =0x00040003     @ h0 = 3 + 4j
    smlsd   r0, r1, r2, r0      @ r0 += 1*3 - 2*4 = -5
    ldr     r1, =0xFFFE0005     @ x1 = 5 - 2j  (signed, im=-2)
    ldr     r2, =0x0006FFFF     @ h1 = -1 + 6j (re=-1, im=6)
    smlsd   r0, r1, r2, r0      @ r0 += 5*(-1) - (-2)*6 = -5 + 12 = 7
loop:
    b   loop
```

**Walkthrough:**

1. The packing convention is `Rn = [im:re]` and `Rm = [im:re]`; SMLSD then computes `re·re − im·im` per pair, exactly the real component of `x·h`.
2. Two SMLSDs accumulate the real-axis output of a 2-tap complex mixer into `r0`.
3. In a real Hilbert filter you'd interleave this loop with an SMLADX-driven loop building the imaginary output — together they form the analytic-signal reconstruction core.

## See also

- [SMLAD](SMLAD.md) — dual MAC, non-exchanged, accumulate
- [SMLADX](SMLADX.md) — dual MAC, exchanged second operand
- [SMLSDX](SMLSDX.md) — dual multiply-subtract, exchanged
- [SMUAD](SMUAD.md) — same dual sum without accumulator
- [SMUADX](SMUADX.md) — exchanged dual sum, no accumulator
- [SMUSD](SMUSD.md) — dual difference, no accumulator
- [SMUSDX](SMUSDX.md) — exchanged dual difference, no accumulator
- [SMLALD](SMLALD.md) — 64-bit accumulator version
- [PKHBT](PKHBT.md) — pack two halfwords into the lane layout these instructions consume

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLSD*.
