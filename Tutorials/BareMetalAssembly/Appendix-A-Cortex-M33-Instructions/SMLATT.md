# SMLATT — Signed 16×16 multiply (top half of `Rn` × top half of `Rm`), accumulate into `Ra`.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLATT <Rd>, <Rn>, <Rm>, <Ra>
```

**When you'd actually use this** is the top-half × top-half MAC that pairs with `SMLABB` to drain a packed-Q15 word in two instructions. With samples and coefficients packed as `[T|B]` (top in bits 31:16, bottom in bits 15:0), one `LDR` + `SMLABB` + `SMLATT` does two FIR taps per loaded word — half the load bandwidth of unpacked Q15. Without `SMLATT` you'd `LSR #16`, sign-extend, `MUL`, then `ADD` — four instructions for what one does. The killer use is packed Q15 FIR/IIR inner loops and right-channel processing in stereo audio.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | R0–R12, LR; not PC/SP |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |
| `<Ra>` | accumulator GPR | R0–R12, LR |

## Operation (pseudocode)

```text
prod32 = SInt(Rn[31:16]) * SInt(Rm[31:16])
result = SInt(Ra) + prod32                 // 33-bit signed add
Rd = result[31:0]
if SignedOverflow(Ra, prod32) then APSR.Q = 1
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | ✓ |

Sets `Q` on signed overflow of the accumulate or dual-sum step. `N`, `Z`, `C`, `V` are never touched.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMLATT` Rd, Rn, Rm, Ra |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

## Example

### Example 1 — Both top halves, accumulate

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMLATT demo: both top halves
    movs    r0, #0
    ldr     r1, =0x00020000     @ top = 2
    ldr     r2, =0x00030000     @ top = 3
    smlatt  r0, r1, r2, r0      @ r0 += 2*3 = 6
loop:
    b   loop
```

**Walkthrough:**

1. Top 16 bits of each register are taken as signed int16.
2. `smlatt` accumulates their product. Pairs nicely with `SMLABB` to consume two stereo channels in one register each.

### Example 2 — Completing a 2-tap FIR step with SMLABB + SMLATT

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Two packed Q15 taps in one inner-loop iteration.
    @ Layout: r1 = [s1 | s0], r2 = [c1 | c0]   ([T | B], top=31:16, bottom=15:0).
    movs    r0, #0
    ldr     r1, =0x00030002     @ s1=3, s0=2
    ldr     r2, =0x00050004     @ c1=5, c0=4
    smlabb  r0, r1, r2, r0      @ r0 += s0*c0 = 8
    smlatt  r0, r1, r2, r0      @ r0 += s1*c1 = 23
loop:
    b   loop
```

**Walkthrough:**

1. `SMLABB` consumes the bottom halves; `SMLATT` consumes the top halves — same two registers, no extra loads.
2. Final `r0 = 8 + 15 = 23` (Q30 if interpreting the halves as Q15).
3. Two cycles, two taps. The unpacked equivalent would burn two extra `LDR`s plus shifts/sign-extends per tap.

## See also

- [SMLABB](SMLABB.md) — halfword MAC variant (BB)
- [SMLABT](SMLABT.md) — halfword MAC variant (BT)
- [SMLATB](SMLATB.md) — halfword MAC variant (TB)
- [SMLAWB](SMLAWB.md) — halfword MAC variant (WB)
- [SMLAWT](SMLAWT.md) — halfword MAC variant (WT)
- [SMULTT](SMULTT.md) — same product without accumulator
- [SMLAL](SMLAL.md) — 64-bit signed multiply-accumulate (full 32×32)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLATT*.
