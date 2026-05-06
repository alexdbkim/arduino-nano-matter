# USUB16 — unsigned wrap-around per-lane subtract of packed halfwords

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
USUB16 <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — The standout use of `USUB16` is **per-lane unsigned compare**: `USUB16 t, a, b; SEL r, a, b` is a 2-instruction packed unsigned max (swap to get min). **`APSR.GE` is set on each lane that did NOT borrow** — i.e., where `Rn ≥ Rm` — and `SEL` reads exactly those bits to pick per-lane between `Rn` and `Rm`. The mod-2^16 difference written to `Rd` is usually thrown away; the flags are why you ran the instruction. The scalar equivalent for two halfword lanes is ~6 instructions with branches.

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
        x = UInt(Rn<lane i>) − UInt(Rm<lane i>)
        Rd<lane i> = x<15:0>             // wraps modulo 2^16
        APSR.GE<bits for lane i> = lane_ok(x)
```

`USUB16` treats each 32-bit register as 2× 16-bit lanes packed in each 32-bit register and applies the modulo (wrap-around) rule independently to every lane.

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

### Example 1 — Per-lane unsigned halfword subtract

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ USUB16 demo: per-lane subtract on packed halfwords.
    movw    r1, #0x0200
    movt    r1, #0x1000
    movw    r2, #0x0002
    movt    r2, #0x0001
    usub16  r0, r1, r2          @ USUB16: unsigned, lane-wise
loop:
    b   loop
```

**Walkthrough:**

1. The two `movw`/`movt` pairs build 32-bit packed operands in `r1` and `r2`.
2. `usub16 r0, r1, r2` treats each register as 2 packed halfword lanes and subtracted them lane-by-lane.
3. `APSR.GE` bits flag the lanes whose unsigned subtract had **no borrow** (i.e. `Rn ≥ Rm`).

### Example 2 — Packed unsigned halfword max via USUB16 + SEL

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Unsigned packed max of two halfword lanes via USUB16 + SEL.
    @ For each lane: GE := (Rn ≥ Rm) → SEL picks Rn, else Rm.
    movw    r1, #0x00C0              @ a.lo = 0x00C0
    movt    r1, #0x1000              @ a.hi = 0x1000
    movw    r2, #0x00FF              @ b.lo = 0x00FF
    movt    r2, #0x0FFF              @ b.hi = 0x0FFF
    usub16  r3, r1, r2               @ r3 discarded; APSR.GE[i] = (a.lane_i ≥ b.lane_i)
    sel     r0, r1, r2               @ r0 = packed unsigned halfword max(a, b)
loop:
    b   loop
```

**Walkthrough:**

1. `USUB16` does `a − b` per halfword. `r3` is throwaway — only `APSR.GE` matters here.
2. For each lane, `GE` is set when `a ≥ b` (no borrow); cleared otherwise.
3. `SEL` consumes those GE bits to pick `r1` (a) on lanes where it won, `r2` (b) where it lost — yielding the packed unsigned max in `r0`. Two instructions, no branches.

## See also

- [UADD8](UADD8.md) — same family
- [UADD16](UADD16.md) — same family
- [USUB8](USUB8.md) — same family
- [SEL](SEL.md) — consume the GE flags this instruction sets

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *USUB16*.
