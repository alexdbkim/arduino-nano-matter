# SSAT16 — signed saturate two packed halfwords in parallel

## Class & availability

- **Class:** Saturation (DSP-SIMD)
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅ (Cortex-M33 on the EFR32MG24 is built with the DSP extension)
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SSAT16{<c>}{<q>} <Rd>, #<imm>, <Rn>
```

Treats `<Rn>` as two packed signed 16-bit halfwords (`Rn[31:16]` and `Rn[15:0]`), saturates each independently to `<imm>` bits, sign-extends each back to 16 bits and re-packs into `<Rd>`. No pre-shift operand exists for SSAT16.

**When you'd actually use this**: when you've been running a DSP-SIMD pipeline (e.g. `SADD16` / halving accumulators) on stereo audio or I/Q radio samples held two-per-register, and you need to convert that packed pair back into a packed `int16|int16` for the DAC or codec. One `SSAT16` clips both lanes in a single cycle, where two scalar `SSAT`s plus a `PKHBT` would cost three. The catch versus scalar `SSAT`: there is no pre-shift operand, so do any Q-format normalisation with a separate `ASR` first. The sticky `Q` flag is OR'd across both lanes — you can tell *something* clipped, never *which* lane, and you can only clear it with `MSR APSR_nzcvq` (no `Bxx`-on-Q).

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR |
| `#<imm>` | saturation width in bits | 1–16 |
| `<Rn>` | source register | R0–R12, LR (two packed `int16`) |

## Operation (pseudocode)

```text
if ConditionPassed() then
    (lo, sat1) = SignedSatQ(SInt(R[n]<15:0>),  imm)
    (hi, sat2) = SignedSatQ(SInt(R[n]<31:16>), imm)
    R[d]<15:0>  = SignExtend(lo, 16)
    R[d]<31:16> = SignExtend(hi, 16)
    if sat1 || sat2 then APSR.Q = '1'
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | ✓ |

`Q` is set if *either* lane saturated. **Q is sticky** — you cannot tell which lane clipped, and you can only clear it with `MSR APSR_nzcvq, Rn`.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SSAT16 <Rd>, #<imm1..16>, <Rn>` |

DSP-extension instruction; 32-bit Thumb only.

## Exceptions / faults

- (none).

## Example

### Example 1 — two stereo samples to a 12-bit DAC

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Two stereo audio samples packed as int16|int16. Clip both to 12-bit DAC.
    ldr     r0, =0x1F40EC78     @ hi = +8000, lo = -5000
    ssat16  r1, #12, r0         @ hi → +2047, lo → -2048; APSR.Q = 1

    @ Halve two halfwords then clip to 8-bit signed range in parallel.
    ldr     r0, =0x01000200     @ hi = +256, lo = +512
    asr     r2, r0, #1          @ note: ASR pre-shift not available on SSAT16
    ssat16  r3, #8, r2          @ each lane independently clipped to [-128,127]
loop:
    b   loop
```

**Walkthrough:**

1. `ssat16 r1, #12, r0` — splits `r0` into two `int16` lanes, clamps each into `[-2048, +2047]`, repacks. `+8000` → `+2047`, `-5000` → `-2048`, and `APSR.Q` flips on. Cheaper than two `SSAT` instructions when you're processing stereo or I/Q sample pairs.
2. `asr r2, r0, #1` — there is no shift operand on `SSAT16`, so do the scaling by hand. This is the part that bites people coming from `SSAT`: only the scalar form has the optional `LSL`/`ASR`.
3. `ssat16 r3, #8, r2` — clips both halfwords to signed 8 bits; the lower lane (`+512` → `+255` after the shift to `+256`) is preserved; if either had clipped, `Q` would still latch.

### Example 2 — packed pair clipped to Q12

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Two channel accumulators packed as int16|int16; clip each to signed 12-bit.
    ldr     r0, =0x12340FED     @ hi = +0x1234 (+4660), lo = +0x0FED (+4077)
    ssat16  r1, #12, r0         @ both > +2047 → both clip to +2047, Q=1

    @ Negative excursions in both lanes — only the lo lane is past the floor.
    ldr     r0, =0xF800F000     @ hi = -2048 (at min, fits), lo = -4096 (clips)
    ssat16  r2, #12, r0         @ hi → -2048, lo → -2048; Q stays 1

    @ Mixed-fit lanes: hi clips, lo OK.
    ldr     r0, =0x70000400     @ hi = +28672, lo = +1024
    ssat16  r3, #12, r0         @ hi → +2047, lo → +1024 (unchanged)

    @ Drain Q.
    mrs     r4, apsr
    bic     r4, r4, #(1 << 27)
    msr     APSR_nzcvq, r4
loop:
    b   loop
```

**Walkthrough:**

1. First `ssat16` — both lanes clip in the same instruction; one cycle does the work of two scalar `SSAT`s plus a `PKHBT` repack. `Q` latches to indicate at least one lane clipped (it can't tell you both did).
2. Second `ssat16` — illustrates the "negative side" of the signed 12-bit range. `−2048` is exactly the Q12 floor and passes through; `−4096` clamps up to `−2048`. `Q` is sticky and remains `1` from the first instruction.
3. Third `ssat16` — only the high lane saturates this time, but you cannot detect "the high lane is the problem" from `Q` alone. If lane-attribution matters (e.g. left vs right channel diagnostics), you must compare lanes against the rails yourself with `SXTH` + `CMP`.
4. `MRS`/`BIC #(1<<27)`/`MSR APSR_nzcvq` is the only path to clear Q. There is no `Bxx`-on-Q, so the read must go through APSR.

## See also

- [SSAT](SSAT.md) — scalar 32-bit signed saturate (with optional pre-shift)
- [USAT16](USAT16.md) — unsigned packed-halfword saturate (DSP)
- [QADD16](QADD16.md) / [QSUB16](QSUB16.md) — signed saturating SIMD add/subtract
- [PKHBT](PKHBT.md) / [PKHTB](PKHTB.md) — pack two halfwords into one word

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.x — *SSAT16*.
