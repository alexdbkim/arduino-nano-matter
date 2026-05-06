# SMULTB — Signed 16×16 multiply: top half of `Rn` × bottom half of `Rm` → 32-bit `Rd`.

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMULTB <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** is the mirror of `SMULBT`: top of `Rn` × bottom of `Rm`. With packed Q15 storage (`[T|B]` — top half is bits 31:16, bottom is bits 15:0), this gives you the cross-term in a complex multiply `(a+bi)(c+di)` where a complex pair is stored as `[b|a]` in one register, since it picks the imaginary `b` and the real `c` in one cycle. Without `SMULTB` you'd shift-right + sign-extend one operand, then a full 32×32 `SMULL` — at least three instructions for what `SMULTB` does in one. Tied to packed Q15 sample storage as the killer use.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | R0–R12, LR; not PC/SP |
| `<Rn>` | first source GPR | R0–R12, LR |
| `<Rm>` | second source GPR | R0–R12, LR |

## Operation (pseudocode)

```text
Rd = SInt(Rn[31:16]) * SInt(Rm[15:0])    // 16×16 → 32 signed
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

This instruction never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMULTB` Rd, Rn, Rm |

No 16-bit encoding exists. This is a Thumb-2 / DSP-extension instruction only.

## Exceptions / faults

- (none — register-only operation)

## Example

### Example 1 — high(Rn) × low(Rm) signed product

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMULTB demo: high(Rn) * low(Rm)
    ldr     r1, =0x00040000     @ Rn high = 4
    ldr     r2, =0x00000003     @ Rm low  = 3
    smultb  r0, r1, r2          @ r0 = 12
loop:
    b   loop
```

**Walkthrough:**

1. `smultb` multiplies `Rn[31:16]` by `Rm[15:0]` (both signed).
2. The other halves are ignored — let you reuse a register that already had one int16 packed into either lane.

### Example 2 — Complex multiply cross-term (b × c)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Complex multiply (a+bi)(c+di): real = a*c - b*d, imag = a*d + b*c.
    @ Packed layout: r1 = [b | a], r2 = [d | c]   ([T|B], top=31:16, bottom=15:0).
    @ SMULTB grabs the b*c cross term from a single instruction.
    ldr     r1, =0x00030002     @ b=3, a=2
    ldr     r2, =0x00050004     @ d=5, c=4
    smultb  r0, r1, r2          @ r0 = b*c = 3*4 = 12
loop:
    b   loop
```

**Walkthrough:**

1. `T` picks bits 31:16 of `r1` (the imaginary part `b=3`); `B` picks bits 15:0 of `r2` (the real part `c=4`).
2. The other three terms (`a*c`, `a*d`, `b*d`) come from `SMULBB`, `SMULBT`, `SMULTT` on the same two registers — four instructions, no reloads, no shifts.

## See also

- [SMULBB](SMULBB.md) — halfword MUL variant (BB)
- [SMULBT](SMULBT.md) — halfword MUL variant (BT)
- [SMULTT](SMULTT.md) — halfword MUL variant (TT)
- [SMULWB](SMULWB.md) — halfword MUL variant (WB)
- [SMULWT](SMULWT.md) — halfword MUL variant (WT)
- [SMLATB](SMLATB.md) — same product, plus accumulator
- [MUL](MUL.md) — plain 32×32 → low 32 multiply

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SMULTB*.
