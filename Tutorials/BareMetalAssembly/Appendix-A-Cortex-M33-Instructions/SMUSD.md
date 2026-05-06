# SMUSD — Dual signed 16×16 multiply, then subtract the two products into a 32-bit register.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMUSD <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — the **real** part of a complex Q15 product `(a+bi)(c+di) = (a·c − b·d) + j(a·d + b·c)` is one SMUSD (`a·c − b·d`). Pair it with SMUADX (`a·d + b·c`) and you have one complete complex multiply in two instructions — the FFT butterfly's arithmetic core. Also the natural choice for the first iteration of a real-axis complex dot product (then continue with SMLSD). Without it an FFT butterfly takes ~6 instructions instead of 2.

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
result = p1 - p2
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
| T1 | 32-bit | `SMUSD` Rd, Rn, Rm |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

## Example

### Example 1 — Real part of complex multiply, no accumulator

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMUSD demo: real part of complex multiply, no accumulator
    ldr     r1, =0x00020001     @ a=1, b=2
    ldr     r2, =0x00040003     @ c=3, d=4
    smusd   r0, r1, r2          @ r0 = 1*3 - 2*4 = -5
loop:
    b   loop
```

**Walkthrough:**

1. Pack `[imag:real]` halves.
2. `smusd` returns `Rn[lo]*Rm[lo] - Rn[hi]*Rm[hi]` — the real part of `(a+bi)(c+di)`.

### Example 2 — SMUSD + SMUADX = full complex multiply (FFT butterfly seed)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Multiply complex sample x = a+bi by twiddle w = c+di.
    @ Result: r0 = Re(x*w) = a*c - b*d, r1 = Im(x*w) = a*d + b*c.
    ldr     r2, =0x00020001     @ x: [b=2 : a=1]
    ldr     r3, =0x00040003     @ w: [d=4 : c=3]
    smusd   r0, r2, r3          @ Re: 1*3 - 2*4 = -5
    smuadx  r1, r2, r3          @ Im: 1*4 + 2*3 = 10
loop:
    b   loop
```

**Walkthrough:**

1. SMUSD seeds the real-axis result; SMUADX seeds the imaginary-axis result.
2. From here you can switch to SMLSD/SMLADX to *accumulate* further complex products — useful for Goertzel filters or single-bin DFT taps.
3. Two-instruction complex multiply is the reason a Q15 FFT on Cortex-M33 runs at audio rates while an M0+ would struggle — for a 256-point FFT it saves roughly ~3 000 cycles.

## See also

- [SMLAD](SMLAD.md) — dual MAC, non-exchanged, accumulate
- [SMLADX](SMLADX.md) — dual MAC, exchanged second operand
- [SMLSD](SMLSD.md) — dual multiply-subtract with accumulate
- [SMLSDX](SMLSDX.md) — dual multiply-subtract, exchanged
- [SMUAD](SMUAD.md) — same dual sum without accumulator
- [SMUADX](SMUADX.md) — exchanged dual sum, no accumulator
- [SMUSDX](SMUSDX.md) — exchanged dual difference, no accumulator
- [SMLALD](SMLALD.md) — 64-bit accumulator version
- [PKHBT](PKHBT.md) — pack two halfwords into the lane layout these instructions consume

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMUSD*.
