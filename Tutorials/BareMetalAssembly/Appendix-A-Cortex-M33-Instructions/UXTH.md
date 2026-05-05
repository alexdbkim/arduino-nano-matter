# UXTH — zero-extend a halfword from a register to 32 bits, with optional rotation

## Class & availability

- **Class:** Bit manipulation
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UXTH{<cond>} <Rd>, <Rm>{, ROR #<rotation>}
```

Optionally rotates `<Rm>` right by 0/8/16/24 bits, takes the bottom 16 bits of the rotated value, and zero-extends to 32 bits in `<Rd>`.

## Operands

| Field        | Type        | Constraints                                                |
|--------------|-------------|------------------------------------------------------------|
| `<Rd>`       | destination | R0–R7 (T1) or R0–R12, LR (T2). Not SP, not PC.             |
| `<Rm>`       | source      | Same constraint as `<Rd>` for the chosen encoding.         |
| `<rotation>` | immediate   | One of `0`, `8`, `16`, `24`. Optional; default is `0`. T1 has no rotation. |

## Operation (pseudocode)

```text
if ConditionPassed() then
    rotated = ROR(Rm, rotation);
    Rd = ZeroExtend(rotated<15:0>, 32);
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width  | Form                                            | Notes                                |
|---------|--------|-------------------------------------------------|--------------------------------------|
| T1      | 16-bit | `1011 0010 10 Rm Rd`                            | Low registers, no rotation.          |
| T2      | 32-bit | `11111010 0001 1111 1111 Rd 10 rot Rm`          | Full registers; rotation 0/8/16/24.  |

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
    @ UXTH demo: split a 32-bit word into its two unsigned 16-bit halves.
    ldr     r0, =0xCAFEBABE
    uxth    r1, r0               @ r1 = 0x0000BABE  (low halfword)
    uxth    r2, r0, ROR #16      @ r2 = 0x0000CAFE  (high halfword)

    @ Use case: an ADC peripheral returns two 12-bit samples packed into
    @ a 32-bit word. UXTH pulls each sample out cleanly.
    ldr     r3, =0x07FF0123      @ sample1=0x123, sample2=0x7FF
    uxth    r4, r3               @ r4 = 0x0123
    uxth    r5, r3, ROR #16      @ r5 = 0x07FF
loop:
    b   loop
```

**Walkthrough:**

1. `uxth r1, r0` — keeps `r0[15:0]` and zeroes the top half. Faster and shorter than `LDR` + mask.
2. `uxth r2, r0, ROR #16` — rotates first so the upper halfword lands in the lower 16 bits, then zero-extends. One instruction, no `LSR #16` needed.
3. The same idiom decodes packed-halfword data from peripherals like SAR-ADCs that pair samples to halve memory bandwidth.

## See also

- [SXTH](SXTH.md) — sign-extending counterpart.
- [UXTB](UXTB.md) — byte version.
- [REV16](REV16.md) — often used together with `UXTH` to byte-swap then extract.
- [UBFX](UBFX.md) — arbitrary-width unsigned extraction.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.229 — *UXTH*.
