# UBFX — extract a bit field and zero-extend it to 32 bits

## Class & availability

- **Class:** Bit manipulation
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UBFX{<cond>} <Rd>, <Rn>, #<lsb>, #<width>
```

Copies `<width>` bits starting at bit `<lsb>` of `<Rn>` into the bottom of `<Rd>`. Bits 31..`<width>` of `<Rd>` are zeroed. The classic "decode a bit field of an MMIO register" instruction.

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
    Rd = ZeroExtend(Rn<msbit:lsb>, 32);
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width  | Form                                                  |
|---------|--------|-------------------------------------------------------|
| T1      | 32-bit | `11110(0)11110 0 Rn (imm3) Rd (imm2)(0) widthm1`      |

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
    @ UBFX demo: decode the PRIMASK / SCB->ICSR-style register field.
    @ Pretend r0 holds a value where bits [11:0] are an exception number,
    @ bits [16:12] are a vector index, and bit 22 is "is_pending".
    ldr     r0, =0x0040A123      @ vector=0, exc#=0xA123? — let's decode it
    ubfx    r1, r0, #0,  #12    @ r1 = exception number  -> 0xA123 & 0xFFF = 0x123
    ubfx    r2, r0, #12, #5     @ r2 = vector index      -> 0x0A
    ubfx    r3, r0, #22, #1     @ r3 = is_pending bit    -> 1
loop:
    b   loop
```

**Walkthrough:**

1. `ubfx r1, r0, #0, #12` — pulls the bottom 12 bits straight out. Equivalent to `r0 & 0xFFF` but does not need a constant load.
2. `ubfx r2, r0, #12, #5` — extracts 5 bits starting at bit 12 and puts them in `r2[4:0]`. Equivalent to `(r0 >> 12) & 0x1F` in one instruction.
3. `ubfx r3, r0, #22, #1` — single-bit extract; result is 0 or 1. Cleaner than `LSR + AND #1`.

Use `UBFX` whenever you'd write `(reg >> shift) & mask` in C — it's one cycle and reads better in disassembly.

## See also

- [SBFX](SBFX.md) — same shape, but sign-extends the extracted field.
- [BFC](BFC.md) / [BFI](BFI.md) — clear or insert a field; the write-side of bit-field manipulation.
- [UXTB](UXTB.md) / [UXTH](UXTH.md) — fixed-width unsigned extension when the field is byte- or halfword-aligned.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.215 — *UBFX*.
