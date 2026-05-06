# SHSUB16 — signed halving per-lane subtract of packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SHSUB16 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this**: `SHSUB16` is the centered-difference operator for packed int16 streams: `(a − b) / 2` per lane, in one cycle, with **zero** chance of overflow even in the worst case `+32767 − (−32768)`. Use it to compute discrete derivatives on stereo audio (`d[n] = (x[n] − x[n−1])/2`), or as the diff stage of a Haar wavelet on a 16-bit signal. Without `SHSUB16` you'd sign-extend each lane to 32 bits, subtract, `ASR #1`, and repack — six instructions for what is one here.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | `R0`–`R12`, `LR` (not `PC`/`SP`) |
| `<Rn>` | first source GPR | same constraints as `<Rd>` |
| `<Rm>` | second source GPR | same constraints as `<Rd>` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    for i in 0..1:
        x = SInt(Rn<lane i>) − SInt(Rm<lane i>)
        Rd<lane i> = (x >> 1)<15:0>     // arithmetic shift
```

`SHSUB16` treats each 32-bit register as 2× 16-bit lanes packed in each 32-bit register and applies the halving signed (result = (a±b) >> 1) rule independently to every lane.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never sets any flag. Halving guarantees the result fits, so there is nothing to report.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | Thumb-2 only — there is **no** 16-bit encoding |

There is no 16-bit Thumb encoding for this instruction; the assembler always emits the 32-bit form.

## Exceptions / faults

- (none) — register-to-register only, no memory access.

## Example

### Example 1 — Per-lane subtract on signed packed halfwords

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SHSUB16 demo: per-lane subtract on packed halfwords.
    movw    r1, #0x0200
    movt    r1, #0x1000
    movw    r2, #0x0002
    movt    r2, #0x0001
    shsub16  r0, r1, r2          @ SHSUB16: signed, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `shsub16 r0, r1, r2` treats each register as 2 packed halfword lanes and subtracted them lane-by-lane.
3. Each lane result is **arithmetic-shifted right by 1** so the sum cannot overflow.

### Example 2 — Centered difference on int16 stereo audio

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Centered finite-difference on two int16 stereo samples without overflow,
    @ even at extreme values:  d[lane] = (x[lane] - y[lane]) / 2
    movw    r1, #0x4000           @ x_lo (L) = +16384
    movt    r1, #0x7FFF           @ x_hi (R) = +32767  (max positive)
    movw    r2, #0x2000           @ y_lo (L) =  +8192
    movt    r2, #0x8000           @ y_hi (R) = -32768  (max negative)
    shsub16 r0, r1, r2            @ r0[lo]=(+16384-+8192)/2, r0[hi]=(+32767-(-32768))/2
loop:
    b       loop
```

**Walkthrough:**

1. The R-channel difference `+32767 − (−32768) = +65535` is the worst case — it cannot fit in int16 by itself.
2. `shsub16` does the subtraction in 17-bit precision internally, then arithmetic-shifts each lane right by 1, producing `+32767` (still the max representable int16) without ever touching `Q` or saturating.
3. This single-cycle behaviour replaces an `SXTH`-pair / `SUB` / `ASR` / `PKHBT` chain that would otherwise be needed to keep the result valid.

## See also

- [SHADD8](SHADD8.md) — same family
- [SHADD16](SHADD16.md) — same family
- [SHSUB8](SHSUB8.md) — same family
- [PKHBT](PKHBT.md) — rebuild a packed halfword pair after halving

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SHSUB16*.
