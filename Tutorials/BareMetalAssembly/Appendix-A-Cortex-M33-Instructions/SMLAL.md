# SMLAL — signed multiply and accumulate into a 64-bit pair

## Class & availability

- **Class:** Multiply (arithmetic)
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SMLAL{<cond>} <RdLo>, <RdHi>, <Rn>, <Rm>
```

`RdHi:RdLo = (RdHi:RdLo) + SignExtend(Rn) × SignExtend(Rm)`. Treats both factors as signed and sign-extends the partial product before adding to the 64-bit accumulator.

**When you'd actually use this**: SMLAL is the workhorse of high-dynamic-range DSP — FIR/IIR filters with Q31 coefficients applied to Q15 samples and accumulated in Q63 so long convolutions cannot overflow. It also shows up in big-integer multiply-accumulate inner loops (Karatsuba, Montgomery multiplication). One instruction does what would otherwise be `SMULL` + a 64-bit add — a real two-cycle saving per tap. Remember to seed `RdLo:RdHi` to a sane signed 64-bit value before the first SMLAL; leaving them undefined silently corrupts the accumulator.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<RdLo>` | low 32 bits of accumulator — read AND written | `R0`–`R12` |
| `<RdHi>` | high 32 bits of accumulator — read AND written | `R0`–`R12`, must differ from `<RdLo>` |
| `<Rn>` | first factor (signed) | `R0`–`R12` |
| `<Rm>` | second factor (signed) | `R0`–`R12` |

**Operand order:** low first, then high. Initialise the pair before the first SMLAL (usually with `movs RdLo, #0; movs RdHi, #0` if you want a zero start, or load a 64-bit bias).

## Operation (pseudocode)

```text
if ConditionPassed() then
    acc    = (SInt(R[dHi]) << 32) | UInt(R[dLo])      // signed 64-bit
    result = acc + SInt(R[n]) * SInt(R[m])
    R[dHi] = result<63:32>
    R[dLo] = result<31:0>
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never on Armv8-M.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `SMLAL RdLo, RdHi, Rn, Rm` (32-bit only) |

## Exceptions / faults

- (none).

## Example

### Example 1 — signed dot product into a 64-bit accumulator

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SMLAL demo: signed dot product into a 64-bit accumulator
    @ acc = a0*b0 + a1*b1 (signed, no overflow even with worst-case 32-bit inputs)
    movs    r4, #0              @ acc.lo
    movs    r5, #0              @ acc.hi

    ldr     r0, =-1000          @ a0
    ldr     r1, = 2000          @ b0
    smlal   r4, r5, r0, r1      @ acc += -2_000_000

    ldr     r0, = 3000          @ a1
    ldr     r1, =-4000          @ b1
    smlal   r4, r5, r0, r1      @ acc += -12_000_000  -> acc = -14_000_000
loop:
    b       loop
```

**Walkthrough:**

1. The accumulator is initialised to 0 across both registers. SMLAL needs the pair to already hold a sane signed value; you can also seed it with a non-zero bias (split into lo/hi) before the loop.
2. Each `smlal` adds a signed product to the 64-bit accumulator in one cycle. Even with two `INT32_MIN × INT32_MAX` products you cannot overflow 64 bits — that's the whole point of accumulating wide.

### Example 2 — seed the accumulator with a non-zero bias, then MAC

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global reset_handler
    .thumb_func
reset_handler:
    ldr     r4, =0x10000000     @ acc.lo bias
    movs    r5, #0              @ acc.hi = 0  (acc starts at +0x10000000)
    ldr     r0, =-32768         @ Q15 sample (-1.0)
    ldr     r1, =-32768         @ Q15 coefficient (-1.0)
    smlal   r4, r5, r0, r1      @ acc += (-1.0) * (-1.0) in Q30 = +0x40000000
loop:
    b       loop
```

**Walkthrough:**

1. Initialising `r5:r4` to `0x00000000_10000000` shows that SMLAL really does *read* its destination — the new product is added to whatever signed 64-bit value is already there.
2. `smlal r4, r5, r0, r1` adds the signed 64-bit product `(-32768) × (-32768) = +0x40000000` to the accumulator, leaving `r5:r4 = 0x00000000_50000000`.
3. In a real Q15 FIR you'd run this inside a tight loop with one SMLAL per tap; the 64-bit headroom guarantees no overflow even after thousands of taps with worst-case inputs.

## See also

- [SMULL](SMULL.md) — non-accumulating signed multiply
- [UMLAL](UMLAL.md) — unsigned accumulating multiply
- [MLA](MLA.md) — 32-bit accumulating multiply

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.171 — *SMLAL*.
