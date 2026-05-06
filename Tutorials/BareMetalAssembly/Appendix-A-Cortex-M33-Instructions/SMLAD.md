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

**When you'd actually use this** — every serious FIR / convolution / dot-product inner loop on Cortex-M33. SMLAD does **two** 16×16 multiplies *and* one 32-bit accumulate in a single cycle, so a Q15 FIR runs at roughly **0.5 cycle per tap**. Without it you'd need two `SMULBB`/`SMULTT` plus an `ADD` (~4–6 cycles per tap, an order of magnitude slower). CMSIS-DSP's `arm_fir_q15` is built on top of this exact opcode, and every Bluetooth-audio decoder and biquad chain on the Nano Matter's EFR32MG24 leans on it.

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

### Example 1 — Single dual-MAC step (2 FIR taps in one instruction)

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

### Example 2 — Unrolled 8-tap FIR inner body (4 SMLADs = 8 taps)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ 8-tap Q15 FIR body: 8 samples × 8 coefficients in 4 SMLAD instructions.
    @ r4 -> sample buffer, r5 -> coefficient buffer, r0 = accumulator.
    ldr     r4, =samples
    ldr     r5, =coeffs
    movs    r0, #0
    ldr     r1, [r4], #4        @ s1:s0
    ldr     r2, [r5], #4        @ c1:c0
    smlad   r0, r1, r2, r0      @ taps 0..1
    ldr     r1, [r4], #4        @ s3:s2
    ldr     r2, [r5], #4        @ c3:c2
    smlad   r0, r1, r2, r0      @ taps 2..3
    ldr     r1, [r4], #4
    ldr     r2, [r5], #4
    smlad   r0, r1, r2, r0      @ taps 4..5
    ldr     r1, [r4], #4
    ldr     r2, [r5], #4
    smlad   r0, r1, r2, r0      @ taps 6..7
loop:
    b   loop

    .align 2
samples: .word 0x00020001, 0x00040003, 0x00060005, 0x00080007
coeffs:  .word 0x00010001, 0x00010001, 0x00010001, 0x00010001
```

**Walkthrough:**

1. `ldr r1,[r4],#4` post-increments through pre-packed `[s_{k+1}:s_k]` halfword pairs; same for coefficients via `r5`.
2. Each `smlad` folds **two** taps into the running 32-bit sum, so 4 SMLADs cover an 8-tap kernel.
3. Total inner-loop cost: 8 LDRs + 4 SMLADs ≈ 12 cycles for 8 taps — about **1.5 cycles per tap**, including memory traffic. The same loop without SMLAD would be 32+ cycles.

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
