# UHSUB8 — unsigned halving per-lane subtract of packed bytes

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UHSUB8 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this**: `UHSUB8` is the unsigned, per-byte `(a − b)/2` — the workhorse for image-gradient kernels that need differences kept inside a byte, like the early stages of a Canny detector or a frame differencer for motion masks. The halving keeps `0xFF − 0x00 = 0xFF` from "spilling": it collapses to `0x7F`, and there's no saturation step to budget for. The hand-rolled equivalent — `UXTB16`, `SUB`, `LSR #1`, repack — is roughly five instructions; `UHSUB8` is one cycle, four lanes at a time.

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
        Rd<lane i> = (x >> 1)<7:0>     // logical shift
```

`UHSUB8` treats each 32-bit register as 4× 8-bit lanes packed in each 32-bit register and applies the halving unsigned (result = (a±b) >> 1) rule independently to every lane.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never sets any flag. Halving guarantees the result fits, so there is nothing to report.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | Thumb-2 only — there is **no** 16-bit encoding |

There is no 16-bit Thumb encoding for this instruction; the assembler always emits the 32-bit form.

## Exceptions / faults

- (none) — register-to-register only, no memory access.

## Example

### Example 1 — Per-lane subtract on unsigned packed bytes

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ UHSUB8 demo: per-lane subtract on packed bytes.
    movw    r1, #0x3040
    movt    r1, #0x1020
    movw    r2, #0x0101
    movt    r2, #0x0101
    uhsub8  r0, r1, r2          @ UHSUB8: unsigned, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `uhsub8 r0, r1, r2` treats each register as 4 packed byte lanes and subtracted them lane-by-lane.
3. Each lane result is **logical-shifted right by 1** so the sum cannot overflow.

### Example 2 — Per-byte image gradient via centered difference

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Per-byte image gradient: 4 differences of adjacent pixels in one cycle, halved to keep range.
    movw    r1, #0x80FF           @ p0=0xFF, p1=0x80
    movt    r1, #0x4020           @ p2=0x20, p3=0x40
    movw    r2, #0x0040           @ q0=0x40, q1=0x00
    movt    r2, #0x80C0           @ q2=0xC0, q3=0x80
    uhsub8  r0, r1, r2            @ r0[i] = (p[i] - q[i]) >> 1, unsigned, lane-wise
loop:
    b       loop
```

**Walkthrough:**

1. `r1` and `r2` each pack four `uint8` pixels — adjacent samples whose difference is the local gradient.
2. `uhsub8` does the byte-wise subtraction in 9-bit precision, then logical-shifts each lane right by 1.
3. Lane 0 gives `(0xFF − 0x40)/2 = 0x5F`; lane 2 gives `(0x20 − 0xC0)/2`, which wraps to `0xB0` (the wrap is the standard `uint8` modulo behaviour, useful when you want a signed-magnitude delta encoded as a byte). Either way, the result fits in 8 bits — no spill, no saturation, four pixels per cycle.

## See also

- [UHADD8](UHADD8.md) — same family
- [UHADD16](UHADD16.md) — same family
- [UHSUB16](UHSUB16.md) — same family
- [PKHBT](PKHBT.md) — rebuild a packed halfword pair after halving

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *UHSUB8*.
