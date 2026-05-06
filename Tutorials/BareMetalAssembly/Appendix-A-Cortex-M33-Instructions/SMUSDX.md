# SMUSDX — Dual signed 16×16 multiply, then subtract the two products (with halves of the second operand exchanged) into a 32-bit register.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMUSDX <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — the cross-difference `a·d − b·c`, which is the imaginary part of `(a+bi)(c−di)` (i.e. multiply by the *conjugate* of `w`). That's how OFDM matched filters, IQ demodulators, and DCT-IV butterflies rotate samples by `e^{−jθ}`. Pair with SMLAD for the corresponding real part (`a·c + b·d`) and you have a 2-cycle conjugate complex multiply — the kernel of every BLE channel-estimator on the EFR32MG24.

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
| T1 | 32-bit | `SMUSDX` Rd, Rn, Rm |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

## Example

### Example 1 — Single cross-difference, no accumulator

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMUSDX demo: cross-difference, no accumulator
    ldr     r1, =0x00020001
    ldr     r2, =0x00040003
    smusdx  r0, r1, r2          @ r0 = 1*4 - 2*3 = -2
loop:
    b   loop
```

**Walkthrough:**

1. Same packing as SMUSD; halves of Rm are exchanged.
2. `smusdx` produces `Rn[lo]*Rm[hi] - Rn[hi]*Rm[lo]`.

### Example 2 — Conjugate complex multiply (rotate by e^{−jθ}) in two instructions

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Conjugate multiply x * conj(w) = (a+bi)(c-di) = (a*c + b*d) + j(b*c - a*d).
    @ With Rn=[b:a] and Rm=[d:c]:
    @   Re = a*c + b*d  -> SMLAD with Ra=0  (or SMUAD)
    @   Im = b*c - a*d  -> -SMUSDX
    @ Use SMUAD for the real axis, SMUSDX for −Im.
    ldr     r2, =0x00020001     @ x: [b=2 : a=1]
    ldr     r3, =0x00040003     @ w: [d=4 : c=3]
    smuad   r0, r2, r3          @ Re: 1*3 + 2*4 = 11
    smusdx  r1, r2, r3          @ -Im: 1*4 - 2*3 = -2  (so Im = +2)
    rsbs    r1, r1, #0          @ negate to get Im = b*c - a*d = +2
loop:
    b   loop
```

**Walkthrough:**

1. SMUSDX gives `a·d − b·c`; the imaginary part of conjugate multiplication is the negative of that, hence the `RSBS` to flip sign.
2. Combined with SMUAD for the real axis, this performs `x · conj(w)` — the operation an IQ demodulator applies every sample to undo a known carrier rotation.
3. The whole rotate-by-conjugate fits in 3 instructions; without DSP it is 6+ instructions and burns roughly 4× the cycles per sample.

## See also

- [SMLAD](SMLAD.md) — dual MAC, non-exchanged, accumulate
- [SMLADX](SMLADX.md) — dual MAC, exchanged second operand
- [SMLSD](SMLSD.md) — dual multiply-subtract with accumulate
- [SMLSDX](SMLSDX.md) — dual multiply-subtract, exchanged
- [SMUAD](SMUAD.md) — same dual sum without accumulator
- [SMUADX](SMUADX.md) — exchanged dual sum, no accumulator
- [SMUSD](SMUSD.md) — dual difference, no accumulator
- [SMLALD](SMLALD.md) — 64-bit accumulator version
- [PKHBT](PKHBT.md) — pack two halfwords into the lane layout these instructions consume

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMUSDX*.
