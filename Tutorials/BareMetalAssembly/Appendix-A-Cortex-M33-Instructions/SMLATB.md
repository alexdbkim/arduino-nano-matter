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
