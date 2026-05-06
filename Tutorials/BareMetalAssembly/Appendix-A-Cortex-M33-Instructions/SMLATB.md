# SMLATB — Signed 16×16 multiply (top half of `Rn` × bottom half of `Rm`), accumulate into `Ra`.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLATB <Rd>, <Rn>, <Rm>, <Ra>
```

**When you'd actually use this** is the mirror cross-lane MAC: top of `Rn` × bottom of `Rm`, accumulated. The classic case is the imaginary part of a complex multiply `(a+bi)(c+di) = (ac-bd) + (ad+bc)i`, where each complex pair is packed as `[b|a]` (top = imaginary, bottom = real). `SMLATB` accumulates the `b*c` cross term in one cycle. Without it you'd shift, sign-extend, `MUL`, then `ADD` — four instructions per cross-term. Packed Q15 storage of complex samples or stereo channels makes this essential.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | R0–R12, LR; not PC/SP |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |
| `<Ra>` | accumulator GPR | R0–R12, LR |

## Operation (pseudocode)

```text
prod32 = SInt(Rn[31:16]) * SInt(Rm[15:0])
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
| T1 | 32-bit | `SMLATB` Rd, Rn, Rm, Ra |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

## Example

### Example 1 — top(Rn) × bottom(Rm), accumulate

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMLATB demo: top of Rn × bottom of Rm
    movs    r0, #0
    ldr     r1, =0x12345678
    ldr     r2, =0xABCD1234
    smlatb  r0, r1, r2, r0      @ r0 += (int16)0x1234 * (int16)0x1234
loop:
    b   loop
```

**Walkthrough:**

1. Same packing as the BT variant but the lanes you select are flipped.
2. `smlatb` does `Rn[31:16] * Rm[15:0]` and adds it to `Ra`.

### Example 2 — Complex multiply, imaginary cross-term `b*c`

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Complex multiply (a+bi)(c+di): imag part = a*d + b*c.
    @ Packed layout: r1 = [b | a], r2 = [d | c]   ([T | B], top=31:16, bottom=15:0).
    @ Use SMLATB to MAC the b*c term into the imaginary accumulator.
    movs    r0, #0
    ldr     r1, =0x00030002     @ b=3, a=2
    ldr     r2, =0x00050004     @ d=5, c=4
    smlatb  r0, r1, r2, r0      @ r0 += b*c = 3*4 = 12
loop:
    b   loop
```

**Walkthrough:**

1. `T` picks bits 31:16 of `r1` (`b=3`); `B` picks bits 15:0 of `r2` (`c=4`).
2. The companion `SMLABT` accumulates `a*d` on the same two registers — two instructions cover the full imaginary part with no reloads or shifts.

## See also

- [SMLABB](SMLABB.md) — halfword MAC variant (BB)
- [SMLABT](SMLABT.md) — halfword MAC variant (BT)
- [SMLATT](SMLATT.md) — halfword MAC variant (TT)
- [SMLAWB](SMLAWB.md) — halfword MAC variant (WB)
- [SMLAWT](SMLAWT.md) — halfword MAC variant (WT)
- [SMULTB](SMULTB.md) — same product without accumulator
- [SMLAL](SMLAL.md) — 64-bit signed multiply-accumulate (full 32×32)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMLATB*.
