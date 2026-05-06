# BFI — copy the low bits of one register into a bit field of another

## Class & availability

- **Class:** Bit manipulation
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
BFI{<cond>} <Rd>, <Rn>, #<lsb>, #<width>
```

Takes the bottom `<width>` bits of `<Rn>` and writes them into `<Rd>` at bit position `<lsb>`. Other bits of `<Rd>` are preserved.

**When you'd actually use this** — packing a value into a peripheral CSR field: a 4-bit DMA channel id, a 3- or 5-bit interrupt priority, a 24-bit address-plus-offset, or a 12-bit ADC reading slotted next to status bits. `BFI` collapses the classic `bic + lsl + orr` triple (plus the `LDR =mask` literal it usually drags along) into a single instruction. Use it any time you'd write `(dst & ~mask) | ((src << shift) & mask)` in C.

## Operands

| Field     | Type        | Constraints                                       |
|-----------|-------------|---------------------------------------------------|
| `<Rd>`    | destination | R0–R12, LR. Not SP, not PC.                       |
| `<Rn>`    | source      | R0–R12, LR. Not SP, not PC. Bits `[width-1:0]` are used. |
| `<lsb>`   | immediate   | 0–31. Position in `<Rd>` of the inserted field.   |
| `<width>` | immediate   | 1–(32 − `<lsb>`).                                 |

## Operation (pseudocode)

```text
if ConditionPassed() then
    msbit = lsb + width - 1;           // 0 ≤ lsb ≤ msbit ≤ 31
    Rd<msbit:lsb> = Rn<width-1:0>;
    // all other bits of Rd preserved
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

`BFI` never updates flags.

## Encodings

| Variant | Width  | Form                                              |
|---------|--------|---------------------------------------------------|
| T1      | 32-bit | `11110(0)11011 0 Rn (imm3) Rd (imm2)(0) msb` (Thumb-2) |

No 16-bit encoding.

## Exceptions / faults

- (none)

## Example

### Example 1 — pack a channel id and 12-bit payload into one word

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ BFI demo: pack a 4-bit channel and 12-bit value into one 32-bit word.
    movs    r0, #0                  @ packed result
    movs    r1, #0xA                @ channel id (4 bits)
    ldr     r2, =0x123              @ payload   (12 bits)
    bfi     r0, r1, #28, #4         @ r0[31:28] = r1[3:0]   -> 0xA0000000
    bfi     r0, r2, #0,  #12        @ r0[11:0]  = r2[11:0]  -> 0xA0000123
    @ r0 = 0xA0000123, channel + payload merged in two instructions
loop:
    b   loop
```

**Walkthrough:**

1. `movs r0, #0` — start with a clean destination so we can see exactly which fields get written.
2. `bfi r0, r1, #28, #4` — copies the low 4 bits of `r1` (`0xA`) into `r0[31:28]`. The rest of `r0` is unchanged.
3. `bfi r0, r2, #0, #12` — copies the low 12 bits of `r2` (`0x123`) into `r0[11:0]`. `r0[31:12]` is preserved, so `r0` ends up as `0xA0000123`.

Use `BFI` whenever you would otherwise write `(dst & ~mask) | ((src << shift) & mask)` — it's a single cycle and never loads a constant.

### Example 2 — insert a 3-bit priority into bits [10:8] of a CSR

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Slot a new 3-bit priority into bits [10:8] of an already-read CSR
    @ value, without disturbing any of the surrounding control bits.
    ldr     r0, =0x12340055      @ existing CSR contents (whatever was read)
    movs    r1, #5               @ new priority value (0..7)
    bfi     r0, r1, #8, #3       @ r0[10:8] = r1[2:0] = 0b101
loop:
    b   loop
```

**Walkthrough:**

1. `ldr r0, =0x12340055` — pretend this is the value you've just read from the peripheral; bits [10:8] currently hold something we want to overwrite.
2. `movs r1, #5` — the new priority. Only its low 3 bits matter; `BFI` will discard anything above bit 2.
3. `bfi r0, r1, #8, #3` — copies `r1[2:0]` into `r0[10:8]`. Every other bit of `r0` (the surrounding 29 bits) is preserved, so you can write `r0` straight back to the CSR without a read-modify-write loop in C.

## See also

- [BFC](BFC.md) — same operand shape, but clears the field instead of inserting.
- [UBFX](UBFX.md) / [SBFX](SBFX.md) — the reverse direction: pull a field *out* of a register.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.19 — *BFI*.
