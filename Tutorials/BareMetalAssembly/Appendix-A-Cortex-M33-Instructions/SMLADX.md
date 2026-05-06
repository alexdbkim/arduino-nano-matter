# SMLADX — Dual signed 16×16 multiply, then add the two products (with halves of the second operand exchanged) and accumulate into a 32-bit register.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLADX <Rd>, <Rn>, <Rm>, <Ra>
```

**When you'd actually use this** — when a complex sample is packed `[real | imag]` in one register, the **imaginary** part of `(a+bi)(c+di) = (ac−bd) + j(ad+bc)` falls out as one SMLADX (`a·d + b·c`). It is the partner of `SMLSD`/`SMUSD`, which give the real part. An FFT butterfly inner loop on M33 is built almost entirely from SMLSD + SMLADX pairs; CMSIS-DSP's `arm_cmplx_dot_prod_q15` uses exactly this combination. Without SMLADX each complex MAC would need two `SMUL*` plus an `SADD` — roughly 3–4× the cycles.

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
| T1 | 32-bit | `SMLADX` Rd, Rn, Rm, Ra |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

## Example

### Example 1 — Single cross dual-MAC step

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMLADX demo: dot product where one operand is stored swapped
    movs    r0, #0
    ldr     r1, =0x00010002     @ Rn = [hi=1, lo=2]
    ldr     r2, =0x00030004     @ Rm = [hi=3, lo=4]
    smladx  r0, r1, r2, r0      @ r0 += 2*3 + 1*4 = 10
loop:
    b   loop
```

**Walkthrough:**

1. `movs r0, #0` — zero the accumulator.
2. Pack Rn and Rm with 16-bit lanes.
3. `smladx` — bottom of Rn (`2`) multiplies top of Rm (`3`), top of Rn (`1`) multiplies bottom of Rm (`4`). Useful when a complex-number array is stored as `[real, imag]` and you want imag×real cross-terms.

### Example 2 — Imaginary part of a complex Q15 dot product (two pairs)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Σ Im((a_k + b_k i)(c_k + d_k i)) = Σ (a_k d_k + b_k c_k) over 2 complex taps.
    @ Operands packed as Rn=[b:a], Rm=[d:c]; SMLADX gives a*d + b*c per pair.
    movs    r0, #0
    ldr     r1, =0x00020001     @ pair 0: b0=2, a0=1
    ldr     r2, =0x00040003     @ pair 0: d0=4, c0=3
    smladx  r0, r1, r2, r0      @ r0 += 1*4 + 2*3 = 10
    ldr     r1, =0x00060005     @ pair 1: b1=6, a1=5
    ldr     r2, =0x00080007     @ pair 1: d1=8, c1=7
    smladx  r0, r1, r2, r0      @ r0 += 5*8 + 6*7 = 82  -> r0 = 92
loop:
    b   loop
```

**Walkthrough:**

1. Each pre-packed register holds one complex sample `(a+bi)` in low/high halves.
2. Each SMLADX folds the cross-products `a·d + b·c` (the imaginary part of one complex multiply) into the running sum.
3. Pairing this loop with an SMLSD-driven loop (real part) gives a **two-instruction-per-complex-MAC** kernel — exactly what CMSIS-DSP `arm_cmplx_mult_cmplx_q15` uses.

## See also

- [SMLAD](SMLAD.md) — dual MAC, non-exchanged, accumulate
- [SMLSD](SMLSD.md) — dual multiply-subtract with accumulate
- [SMLSDX](SMLSDX.md) — dual multiply-subtract, exchanged
- [SMUAD](SMUAD.md) — same dual sum without accumulator
- [SMUADX](SMUADX.md) — exchanged dual sum, no accumulator
- [SMUSD](SMUSD.md) — dual difference, no accumulator
- [SMUSDX](SMUSDX.md) — exchanged dual difference, no accumulator
- [SMLALD](SMLALD.md) — 64-bit accumulator version
- [PKHBT](PKHBT.md) — pack two halfwords into the lane layout these instructions consume

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLADX*.
