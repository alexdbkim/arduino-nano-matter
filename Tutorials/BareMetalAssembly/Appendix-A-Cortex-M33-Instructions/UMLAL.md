# UMLAL — unsigned multiply and accumulate into a 64-bit pair

## Class & availability

- **Class:** Multiply (arithmetic)
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UMLAL{<cond>} <RdLo>, <RdHi>, <Rn>, <Rm>
```

`RdHi:RdLo = (RdHi:RdLo) + ZeroExtend(Rn) × ZeroExtend(Rm)`. Reads *and* writes the 64-bit pair — it's a true accumulator.

**When you'd actually use this**: UMLAL is the 64-bit accumulating multiply for unsigned high-precision arithmetic — running sums of 32-bit unsigned samples (sensor integration over long windows without overflow), big-integer multiply-accumulate inner loops in cryptography (Montgomery, Bignum schoolbook multiply), and fixed-point accumulation when the *single* product already needs more than 32 bits of headroom. One instruction replaces `UMULL` + a 64-bit add. Like SMLAL, you must initialise the destination pair before the first UMLAL — leaving it stale is the easiest way to "accumulate" into garbage.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<RdLo>` | low 32 bits — read AND written | `R0`–`R12` |
| `<RdHi>` | high 32 bits — read AND written | `R0`–`R12`, must differ from `<RdLo>` |
| `<Rn>` | first factor (unsigned) | `R0`–`R12` |
| `<Rm>` | second factor (unsigned) | `R0`–`R12` |

**Operand order:** low-first, then high. The pair must be initialised before the first `UMLAL` — usually with `movs RdLo, #0; movs RdHi, #0`.

## Operation (pseudocode)

```text
if ConditionPassed() then
    acc    = (UInt(R[dHi]) << 32) | UInt(R[dLo])
    result = acc + UInt(R[n]) * UInt(R[m])
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
| T1 | 32-bit | `UMLAL RdLo, RdHi, Rn, Rm` (32-bit only) |

## Exceptions / faults

- (none).

## Example

### Example 1 — running sum of unsigned samples in 64 bits

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ UMLAL demo: 64-bit running sum of unsigned 32-bit samples
    @ r4:r5 will hold the accumulator (lo:hi)
    movs    r4, #0              @ acc.lo = 0
    movs    r5, #0              @ acc.hi = 0
    movs    r6, #1              @ a "weight" (multiplier)

    ldr     r0, =0xFFFFFFFF
    umlal   r4, r5, r0, r6      @ acc += 0xFFFFFFFF * 1
    ldr     r0, =0x00000002
    umlal   r4, r5, r0, r6      @ acc += 2  -> acc = 0x100000001
    @ now r5 = 1, r4 = 1
loop:
    b       loop
```

**Walkthrough:**

1. The accumulator is zeroed in two registers. With UMLAL there is no "first multiply, then accumulate" split — every iteration is one instruction.
2. After two `umlal`s, the running sum has exceeded 2³², so `r5` (the high half) is non-zero. Compare with using plain ADDs into a single register, which would silently lose that bit.

### Example 2 — one limb of an unsigned big-int multiply-by-scalar

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global reset_handler
    .thumb_func
reset_handler:
    movs    r4, #0              @ acc.lo = 0
    movs    r5, #0              @ acc.hi = 0
    ldr     r0, =0xDEADBEEF     @ one 32-bit limb of a bignum
    ldr     r1, =0x00010000     @ scalar to multiply by
    umlal   r4, r5, r0, r1      @ r5:r4 += 0xDEADBEEF * 0x10000
loop:
    b       loop
```

**Walkthrough:**

1. `umlal r4, r5, r0, r1` does the limb's full 64-bit product *and* adds it into the accumulator in one cycle.
2. In a multi-limb routine you'd loop, with each iteration adding into a `(r5:r4)` carry that's then propagated to the next higher limb of the result. UMLAL eliminates one explicit ADD per limb compared to `UMULL` + 64-bit add.
3. Because we initialised the accumulator to zero, this single UMLAL produces the same result as a `UMULL` would — the whole point of UMLAL is the cheap accumulation across many such taps.

## See also

- [UMULL](UMULL.md) — the non-accumulating form
- [SMLAL](SMLAL.md) — the signed counterpart
- [MLA](MLA.md) — 32-bit accumulating multiply

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.228 — *UMLAL*.
