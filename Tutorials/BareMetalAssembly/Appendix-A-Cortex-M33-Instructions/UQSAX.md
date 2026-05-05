# UQSAX — unsigned saturating exchange-then-sub-high/add-low on packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UQSAX <Rd>, <Rn>, <Rm>
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination GPR | `R0`–`R12`, `LR` (not `PC`/`SP`) |
| `<Rn>` | first source GPR | same constraints as `<Rd>` |
| `<Rm>` | second source GPR | same constraints as `<Rd>` |

## Operation (pseudocode)

```text
if ConditionPassed() then
    h = UInt(Rn<31:16>) − UInt(Rm<15:0>)
    l = UInt(Rn<15:0>)  + UInt(Rm<31:16>)
    Rd<31:16> = UnsignedSat(h, 16)
    Rd<15:0>  = UnsignedSat(l, 16)
```

`UQSAX` treats each 32-bit register as two 16-bit lanes packed in each 32-bit register (halves swapped on Rm) and applies the unsigned saturating (clamps to lane range) rule independently to every lane.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never sets `N`/`Z`/`C`/`V`/`GE`. Crucially — and unlike scalar `QADD`/`QSUB` — the SIMD saturating variants do **not** set `APSR.Q` either. Saturation is silent; if you need to detect it, compare the result yourself.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | Thumb-2 only — there is **no** 16-bit encoding |

There is no 16-bit Thumb encoding for this instruction; the assembler always emits the 32-bit form.

## Exceptions / faults

- (none) — register-to-register only, no memory access.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ UQSAX: reverse-cross sub/add on packed halfwords.
    movw    r1, #0x0005
    movt    r1, #0x0003
    movw    r2, #0x0002
    movt    r2, #0x0001
    uqsax    r0, r1, r2          @ r0[hi]=r1[hi] − r2[lo], r0[lo]=r1[lo] + r2[hi]
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `uqsax r0, r1, r2` exchanges the halves of `r2` first, then computes `r0[hi] = r1[hi] − r2[lo]` and `r0[lo] = r1[lo] + r2[hi]`.
3. Each half is then **saturated** to the unsigned 16-bit range `[0, 65535]`.

## See also

- [UQADD8](UQADD8.md) — same family
- [UQADD16](UQADD16.md) — same family
- [UQSUB8](UQSUB8.md) — same family
- [UQASX](UQASX.md) — mirror operation (add on hi, subtract on lo)
- [USAT](USAT.md) — scalar unsigned saturation

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *UQSAX*.
