# CLZ — count leading zero bits in a 32-bit register

## Class & availability

- **Class:** Bit manipulation
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
CLZ{<cond>} <Rd>, <Rm>
```

Writes to `<Rd>` the number of consecutive zero bits at the most-significant end of `<Rm>`. Result is 0 (if bit 31 set) through 32 (if `<Rm>` is zero).

## Operands

| Field   | Type        | Constraints                          |
|---------|-------------|--------------------------------------|
| `<Rd>`  | destination | R0–R12, LR. Not SP, not PC.          |
| `<Rm>`  | source      | R0–R12, LR. Not SP, not PC.          |

## Operation (pseudocode)

```text
if ConditionPassed() then
    Rd = CountLeadingZeroBits(Rm);    // 0..32
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags. There is no `S` form.

## Encodings

| Variant | Width  | Form                                     |
|---------|--------|------------------------------------------|
| T1      | 32-bit | `11111010 1011 Rm 1111 Rd 1000 Rm`       |

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
    @ CLZ demo: fast floor(log2(x)) for x > 0 -> 31 - CLZ(x).
    ldr     r0, =0x00080000      @ x = 524288 = 2^19
    clz     r1, r0               @ r1 = 12  (12 leading zeros)
    rsb     r2, r1, #31          @ r2 = 31 - 12 = 19  -> floor(log2(x))

    movs    r3, #0
    clz     r4, r3               @ r4 = 32 (special case: x == 0)
loop:
    b   loop
```

**Walkthrough:**

1. `ldr r0, =0x00080000` — bit 19 is the highest set bit, so we expect 12 leading zeros (bits 31..20).
2. `clz r1, r0` — produces `12` in `r1`. One cycle, no branches.
3. `rsb r2, r1, #31` — computes `31 - r1`, the index of the topmost set bit, i.e. `floor(log2(x))` when `x > 0`.
4. `clz r4, r3` — for `r3 == 0`, the result is **32**, not undefined. That's the value you should special-case if you're computing a logarithm.

`CLZ` is the building block for fast priority encoders, normalising mantissas in software floats, and finding the highest-priority bit in a bitmap.

## See also

- [RBIT](RBIT.md) — pair with `CLZ` to count *trailing* zeros: `RBIT` then `CLZ`.
- [LSL](LSL.md) / [LSR](LSR.md) — shifts often used together with `CLZ` for normalisation.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.31 — *CLZ*.
