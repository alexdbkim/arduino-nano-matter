# SADD16 — signed wrap-around per-lane add of packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SADD16 <Rd>, <Rn>, <Rm>
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
    for i in 0..1:
        x = SInt(Rn<lane i>) + SInt(Rm<lane i>)
        Rd<lane i> = x<15:0>             // wraps modulo 2^16
        APSR.GE<bits for lane i> = lane_ok(x)
```

`SADD16` treats each 32-bit register as 2× 16-bit lanes packed in each 32-bit register and applies the modulo (wrap-around) rule independently to every lane.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never sets `N`/`Z`/`C`/`V`/`Q`. Updates `APSR.GE[3:0]` per lane: one bit per byte for `…8` variants, two duplicated bits per halfword for `…16`/ASX/SAX variants. Pair with `SEL` to consume them.

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
    @ Stereo audio mixer: add two int16 sample pairs (L,R) packed in r1, r2.
    movw    r1, #0x0456
    movt    r1, #0x1234
    movw    r2, #0x0100
    movt    r2, #0xffe0
    sadd16  r0, r1, r2          @ lane-wise int16 add; GE flags reflect each lane's sign
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `sadd16 r0, r1, r2` treats each register as 2 packed halfword lanes and added them lane-by-lane.
3. `APSR.GE` bits flag the lanes whose signed result is `≥ 0`.

## See also

- [SADD8](SADD8.md) — same family
- [SSUB8](SSUB8.md) — same family
- [SSUB16](SSUB16.md) — same family
- [SEL](SEL.md) — consume the GE flags this instruction sets

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SADD16*.
