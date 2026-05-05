# QSUB16 — signed saturating per-lane subtract of packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
QSUB16 <Rd>, <Rn>, <Rm>
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
        x = SInt(Rn<lane i>) − SInt(Rm<lane i>)
        Rd<lane i> = SignedSat(x, 16)
```

`QSUB16` treats each 32-bit register as 2× 16-bit lanes packed in each 32-bit register and applies the signed saturating (clamps to lane range) rule independently to every lane.

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
    @ QSUB16 demo: per-lane subtract on packed halfwords.
    movw    r1, #0x0200
    movt    r1, #0x1000
    movw    r2, #0x0002
    movt    r2, #0x0001
    qsub16  r0, r1, r2          @ QSUB16: signed, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `qsub16 r0, r1, r2` treats each register as 2 packed halfword lanes and subtracted them lane-by-lane.
3. Each lane is then **saturated** to the signed `16`-bit range — no wrap-around, but `APSR.Q` is **not** updated.

## See also

- [QADD8](QADD8.md) — same family
- [QADD16](QADD16.md) — same family
- [QSUB8](QSUB8.md) — same family
- [QADD](QADD.md) — scalar saturating add (this is the SIMD lane-wise version)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *QSUB16*.
