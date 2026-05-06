# SMUADX — Dual signed 16×16 multiply, then add the two products (with halves of the second operand exchanged) into a 32-bit register.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMUADX <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — the **imaginary** part of a complex Q15 product `(a+bi)(c+di) = (a·c−b·d) + j(a·d+b·c)` — i.e. the `a·d + b·c` term — falls out of one SMUADX. Pair with SMUSD (real part) and you have a complete complex multiply in **two** instructions. That's the entire FFT-butterfly arithmetic: every twiddle in CMSIS-DSP `arm_cfft_q15` rides on this duo. Without them an FFT inner loop needs 4 `SMUL*` + 1 `ADD` + 1 `SUB` (≈6× the work).

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | R0–R12, LR; not PC/SP |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |

## Operation (pseudocode)

```text
p1 = SInt(Rn[15:0])  * SInt(Rm[31:16])
p2 = SInt(Rn[31:16]) * SInt(Rm[15:0])
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
| T1 | 32-bit | `SMUADX` Rd, Rn, Rm |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

## Example

### Example 1 — Single cross dual-add (complex Im part)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMUADX demo: cross-multiply add (e.g. imag part of complex product)
    ldr     r1, =0x00010002
    ldr     r2, =0x00030004
    smuadx  r0, r1, r2          @ r0 = 2*3 + 1*4 = 10
loop:
    b   loop
```

**Walkthrough:**

1. Pack two int16 lanes into each source.
2. `smuadx` exchanges Rm's halves before multiplying — gives the cross-sum `Rn[lo]*Rm[hi] + Rn[hi]*Rm[lo]`.
3. This is exactly the imaginary part of `(a+bi)(c+di)` when complex is laid out as `[imag:real]`.

### Example 2 — Full Q15 complex multiply (FFT butterfly) in two instructions

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Complex multiply (a+bi)(c+di): r0 = Re = a*c - b*d, r1 = Im = a*d + b*c.
    @ Operands packed as [imag:real]: Rn=[b:a], Rm=[d:c].
    ldr     r2, =0x00020001     @ x = 1 + 2j   ([b=2 : a=1])
    ldr     r3, =0x00040003     @ w = 3 + 4j   ([d=4 : c=3])
    smusd   r0, r2, r3          @ Re: 1*3 - 2*4 = -5
    smuadx  r1, r2, r3          @ Im: 1*4 + 2*3 = 10
loop:
    b   loop
```

**Walkthrough:**

1. SMUSD computes `a·c − b·d` (real axis), SMUADX computes `a·d + b·c` (imaginary axis).
2. Together they perform one full complex Q15 multiply in **2 cycles** — exactly what an FFT butterfly needs to multiply a sample by a twiddle factor `e^{−j2πk/N}`.
3. A 1024-point Q15 FFT runs ~5120 butterflies; with this pair that's ~10 K cycles of multiplies vs. ~60 K without DSP — the difference between a real-time spectrogram and a slideshow.

## See also

- [SMLAD](SMLAD.md) — dual MAC, non-exchanged, accumulate
- [SMLADX](SMLADX.md) — dual MAC, exchanged second operand
- [SMLSD](SMLSD.md) — dual multiply-subtract with accumulate
- [SMLSDX](SMLSDX.md) — dual multiply-subtract, exchanged
- [SMUAD](SMUAD.md) — same dual sum without accumulator
- [SMUSD](SMUSD.md) — dual difference, no accumulator
- [SMUSDX](SMUSDX.md) — exchanged dual difference, no accumulator
- [SMLALD](SMLALD.md) — 64-bit accumulator version
- [PKHBT](PKHBT.md) — pack two halfwords into the lane layout these instructions consume

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMUADX*.
