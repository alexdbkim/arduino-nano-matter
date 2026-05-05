# NEG — two's-complement negation (alias for `RSBS Rd, Rn, #0`)

## Class & availability

- **Class:** Arithmetic
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
NEG{S}{<cond>} <Rd>, <Rn>
```

`Rd = 0 − Rn`. `NEG` is **not a real opcode** — it's a unified-syntax mnemonic the assembler rewrites to `RSB{S} Rd, Rn, #0`. There is no separate encoding, no separate timing, no separate behaviour.

In pre-UAL Thumb, `NEG` was an actual 16-bit Thumb-1 instruction (always flag-setting). On Armv8-M unified syntax it survives as an alias; both `neg` and `negs` are accepted and assemble to `rsbs Rd, Rn, #0`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination | `R0`–`R7` (T1 of RSB) or `R0`–`R12` (T2 of RSB) |
| `<Rn>` | source (the value to negate) | same set as `<Rd>` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    (result, carry, overflow) = AddWithCarry(NOT(R[n]), '00000000', '1')
    R[d] = result
    if S == '1' then
        APSR.N = result<31>
        APSR.Z = IsZeroBit(result)
        APSR.C = carry
        APSR.V = overflow
```

**Edge case:** negating `0x80000000` (INT32_MIN) gives `0x80000000` again — the mathematical result `+2³¹` doesn't fit. APSR.V is set if you used the `S` form.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | ✓ | – |

Updated only with the `S` suffix. Outside an IT block the 16-bit form always sets flags (because the underlying 16-bit `RSB` is the negate-only variant, which is implicitly flag-setting).

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | assembles to `RSBS Rd, Rn, #0` (low regs) |
| T2 | 32-bit | assembles to `RSB{S}.W Rd, Rn, #0` |

There is no opcode in the architecture decode that says "this is NEG" — disassemblers will always show it as `RSB`/`RSBS`.

## Exceptions / faults

- (none).

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ NEG demo: negate, then detect the INT_MIN edge case
    ldr     r0, =1234
    neg     r1, r0              @ r1 = -1234, flags untouched? -> see below
    @ explicit flag-setting form, used to detect signed overflow
    ldr     r2, =0x80000000     @ INT32_MIN
    negs    r3, r2              @ r3 = 0x80000000 (unchanged), V=1
    bvs     was_int_min
    nop
was_int_min:
loop:
    b       loop
```

**Walkthrough:**

1. `neg r1, r0` — assembles to `rsbs r1, r0, #0` because the 16-bit RSB encoding is the only one that fits and that encoding always sets flags. So despite the missing `S` in the source, flags **do** update on Cortex-M33 here. If you specifically want flags-untouched semantics, write `rsb.w r1, r0, #0` to force the 32-bit T2 encoding without `S`.
2. `negs r3, r2` — explicitly flag-setting. Negating INT32_MIN sets V=1 because the true result overflows.

## See also

- [RSB](RSB.md) — what NEG actually assembles to
- [SUB](SUB.md) — `subs Rd, #0, Rn` is *not* a thing; that's why RSB/NEG exist
- [MVN](MVN.md) — bitwise NOT, the other "invert" you might mean

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.143 — *RSB (immediate)*. Unified-syntax aliases listed in §C1.6.
