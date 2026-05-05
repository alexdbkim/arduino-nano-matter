# SBFX — extract a bit field and sign-extend it to 32 bits

## Class & availability

- **Class:** Bit manipulation
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SBFX{<cond>} <Rd>, <Rn>, #<lsb>, #<width>
```

Copies `<width>` bits starting at bit `<lsb>` of `<Rn>` into the bottom of `<Rd>`, then sign-extends from the top of the extracted field to fill bits 31..`<width>`.

## Operands

| Field     | Type        | Constraints                                       |
|-----------|-------------|---------------------------------------------------|
| `<Rd>`    | destination | R0–R12, LR. Not SP, not PC.                       |
| `<Rn>`    | source      | R0–R12, LR. Not SP, not PC.                       |
| `<lsb>`   | immediate   | 0–31.                                             |
| `<width>` | immediate   | 1–(32 − `<lsb>`).                                 |

## Operation (pseudocode)

```text
if ConditionPassed() then
    msbit = lsb + width - 1;          // 0 ≤ lsb ≤ msbit ≤ 31
    Rd = SignExtend(Rn<msbit:lsb>, 32);
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width  | Form                                                  |
|---------|--------|-------------------------------------------------------|
| T1      | 32-bit | `11110(0)11010 0 Rn (imm3) Rd (imm2)(0) widthm1`      |

No 16-bit encoding.

## Exceptions / faults

- (none)

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SBFX demo: decode a 12-bit signed ADC sample stored in bits [15:4]
    @ of a packed status register. (Top bit of the field is the sign.)
    ldr     r0, =0xAAAAFFFF      @ pretend register read
    @ field at [15:4] = 0xFFF (= -1 as a signed 12-bit value)
    sbfx    r1, r0, #4, #12      @ r1 = 0xFFFFFFFF (-1)

    @ Positive sample: field [15:4] = 0x123
    ldr     r2, =0x00001230
    sbfx    r3, r2, #4, #12      @ r3 = 0x00000123 (+291), no sign bit set
loop:
    b   loop
```

**Walkthrough:**

1. `ldr r0, =0xAAAAFFFF` — places `0xFFF` in bits [15:4]. As a signed 12-bit value, that's −1.
2. `sbfx r1, r0, #4, #12` — extracts those 12 bits into `r1[11:0]`, then sees that bit 11 of the field is `1` and fills bits 31..12 with ones. Result is `0xFFFFFFFF` — the correctly sign-extended 32-bit `-1`.
3. `sbfx r3, r2, #4, #12` — same operation on a positive field. Bit 11 of the extracted field is `0`, so the upper bits are zeroed. Result is `+0x123`.

Use `SBFX` whenever you'd otherwise do `LSL` to push the field's sign bit to bit 31 followed by an arithmetic `ASR` to bring it back. One instruction, no shift chain.

## See also

- [UBFX](UBFX.md) — same operation, but zero-extends instead of sign-extending.
- [BFI](BFI.md) — the inverse: insert a field rather than extract.
- [SXTB](SXTB.md) / [SXTH](SXTH.md) — fixed-width signed extension (8/16 bits) when the field happens to be byte- or halfword-aligned.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.139 — *SBFX*.
