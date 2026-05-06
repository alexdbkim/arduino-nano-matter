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

**When you'd actually use this** — `USUB8` is most often run for its flags rather than its result: `USUB8 t, a, b; SEL r, a, b` is the canonical 2-instruction byte-wise unsigned max. **One `APSR.GE` bit is written per byte lane — set when that lane did not borrow (i.e. `Rn ≥ Rm`)** — and `SEL` consumes those bits to mux 4 byte lanes between `Rn` and `Rm` in a single instruction. Vectorized min/max/abs of RGBA pixels, per-byte clamping, and motion-detection deltas all become two-instruction sequences. Without `GE`+`SEL` the same logic runs ~10 scalar instructions with conditional branches.

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

### Example 1 — Per-pixel grayscale frame diff

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

### Example 2 — Byte-wise max of two RGBA pixels via SEL

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Per-channel max of two RGBA pixels (R,G,B,A packed as 4 unsigned bytes).
    @ Useful for additive sprite blending / "lighten" mode.
    movw    r1, #0x4080              @ pixel A: B=0x80, G=0x40 (low half)
    movt    r1, #0x10F0              @           A=0x10, R=0xF0 (high half)
    movw    r2, #0xA020              @ pixel B
    movt    r2, #0x40C0
    usub8   r3, r1, r2               @ r3 discarded; APSR.GE[i]=1 iff lane_i of r1 ≥ r2
    sel     r0, r1, r2               @ r0 = byte-wise max(r1, r2) — RGBA "lighten" blend
loop:
    b   loop
```

**Walkthrough:**

1. `USUB8` subtracts pixel B from A across all 4 channels. We don't care about the differences — only the per-lane `APSR.GE` flags.
2. For each byte lane, `GE` is set when A ≥ B (no borrow), cleared when B was bigger.
3. `SEL r0, r1, r2` reads the 4 GE bits and picks A on lanes where it won, B otherwise → the per-channel max.
4. That's the entire "lighten" compositor in **two cycles** for 4 channels at once. The naive scalar version is ~10 instructions with 4 conditional branches.

## See also

- [UADD8](UADD8.md) — same family
- [UADD16](UADD16.md) — same family
- [USUB16](USUB16.md) — same family
- [SEL](SEL.md) — consume the GE flags this instruction sets

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *USUB8*.
