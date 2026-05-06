# MUL — 32-bit multiply, low 32 bits of the product

## Class & availability

- **Class:** Multiply (arithmetic)
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
MUL{S}{<cond>} {<Rd>,} <Rn>, <Rm>
```

`Rd = (Rn × Rm)<31:0>` — the low 32 bits of the 64-bit product. Signed and unsigned multiply produce the same low-32-bit result, so there's only one MUL.

**When you'd actually use this**: 32×32→32 multiply for index calculations (`row*stride + col`), scaling counts by small constants, hash-mixing steps (Knuth multiplicative hash, `x * 0x9E3779B9`), and integer power-of-arbitrary-base. On Cortex-M33 it's a single-cycle op, so it's often the cheapest way to scale — cheaper than a chain of shifts-and-adds for non-trivial multipliers. Reach for `UMULL`/`SMULL` instead the moment you suspect the true product won't fit in 32 bits, because MUL silently throws the high 32 bits away with no flag indication.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | T1: `R0`–`R7`. T2: `R0`–`R12`. |
| `<Rn>` | first factor | same set |
| `<Rm>` | second factor | same set |

If `<Rd>` is omitted it defaults to `<Rn>` (so `mul r0, r1` means `mul r0, r0, r1`).

## Operation (pseudocode)

```text
if ConditionPassed() then
    operand1 = SInt(R[n])           // sign-irrelevant for low 32 bits
    operand2 = SInt(R[m])
    result   = operand1 * operand2
    R[d] = result<31:0>
    if S == '1' then
        APSR.N = result<31>
        APSR.Z = IsZeroBit(result<31:0>)
        // C and V unchanged
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | – | – | – |

Only with the `S` suffix. Even then, **C and V are unaffected** — there is no carry/overflow indication on a 32-bit MUL.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `MULS Rdm, Rn, Rdm` (low regs only, the destination is also a source). Sets flags outside IT. |
| T2 | 32-bit | `MUL.W Rd, Rn, Rm` (no flag form in 32-bit encoding) |

This is the part that bites people: the 32-bit `MUL.W` encoding **cannot** set flags. If you write `muls.w` the assembler will reject it (or silently rewrite). Use the 16-bit `muls` form, or follow `mul` with an explicit `cmp`/`tst`/`movs`.

## Exceptions / faults

- (none). MUL takes 1 cycle on Cortex-M33.

## Example

### Example 1 — area = width × height (and a wraparound product)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ MUL demo: compute area = width * height
    movs    r0, #40             @ width
    movs    r1, #30             @ height
    mul     r2, r0, r1          @ r2 = 1200
    @ low 32 bits of a wraparound product:
    ldr     r3, =0x10000
    ldr     r4, =0x10000
    mul     r5, r3, r4          @ r5 = 0  (true product = 0x100000000, low32 = 0)
loop:
    b       loop
```

**Walkthrough:**

1. `mul r2, r0, r1` — 40×30 = 1200, fits comfortably in 32 bits.
2. `mul r5, r3, r4` — the *true* product is 2⁶⁴ ÷ 2³² = 2³², which wraps the low 32 bits to 0. MUL gives you no warning. If you need the high half, use [UMULL](UMULL.md) / [SMULL](SMULL.md).

### Example 2 — Knuth multiplicative hash (single-cycle mix)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global reset_handler
    .thumb_func
reset_handler:
    ldr     r0, =0x12345678     @ key
    ldr     r1, =0x9E3779B9     @ 2^32 / golden_ratio (Knuth's constant)
    mul     r2, r0, r1          @ low 32 bits of key * constant
    lsr     r2, r2, #20         @ keep top 12 bits as a 12-bit hash bucket
loop:
    b       loop
```

**Walkthrough:**

1. `mul r2, r0, r1` produces only the low 32 bits, but for hashing that's exactly what we want — the *upper* bits of those low 32 are the well-mixed ones.
2. On Cortex-M33 this whole multiplicative-hash step is a single cycle. You'd be hard-pressed to write a faster non-cryptographic mix.
3. Shifting right keeps the upper hash bits (those depend on every input bit). A `% 4096` instead would only ever look at the low 12 bits.

## See also

- [MLA](MLA.md) — multiply and accumulate, `Rd = Rn*Rm + Ra`
- [MLS](MLS.md) — multiply and subtract, `Rd = Ra − Rn*Rm`
- [UMULL](UMULL.md) / [SMULL](SMULL.md) — full 64-bit product

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.108 — *MUL*.
