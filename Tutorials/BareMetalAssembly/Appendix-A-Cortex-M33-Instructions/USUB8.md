# USUB8 — unsigned wrap-around per-lane subtract of packed bytes

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
USUB8 <Rd>, <Rn>, <Rm>
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
    for i in 0..3:
        x = UInt(Rn<lane i>) − UInt(Rm<lane i>)
        Rd<lane i> = x<7:0>             // wraps modulo 2^8
        APSR.GE<bits for lane i> = lane_ok(x)
```

`USUB8` treats each 32-bit register as 4× 8-bit lanes packed in each 32-bit register and applies the modulo (wrap-around) rule independently to every lane.

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
    @ Per-pixel difference of 4 grayscale pixels packed into one word.
    @ r1 = current frame, r2 = previous frame.
    movw    r1, #0x4020
    movt    r1, #0x8060
    movw    r2, #0x3060
    movt    r2, #0x1050
    usub8   r0, r1, r2          @ r0 = r1 − r2 byte-wise; APSR.GE marks lanes with no borrow
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `usub8 r0, r1, r2` treats each register as 4 packed byte lanes and subtracted them lane-by-lane.
3. `APSR.GE` bits flag the lanes whose unsigned subtract had **no borrow** (i.e. `Rn ≥ Rm`).

## See also

- [UADD8](UADD8.md) — same family
- [UADD16](UADD16.md) — same family
- [USUB16](USUB16.md) — same family
- [SEL](SEL.md) — consume the GE flags this instruction sets

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *USUB8*.
