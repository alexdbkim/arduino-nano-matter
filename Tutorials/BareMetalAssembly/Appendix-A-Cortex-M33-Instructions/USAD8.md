# USAD8 — sum of absolute differences across four bytes

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
USAD8  <Rd>, <Rn>, <Rm>
```

**When you'd actually use this** — `USAD8` is the single most powerful integer instruction on Cortex-M33 for video and image work: in *one* cycle it computes the **sum of absolute differences across four packed bytes**, the literal kernel of motion-estimation block matching, optical-flow patch matching, template matching, perceptual hashing, and most image-similarity scores. The scalar equivalent is four `SUB`s, four conditional negates, and three `ADD`s — roughly twelve cycles plus scratch registers. Combined with `USADA8`, a 16×16 motion-estimation block match is ~64 instructions on M33; the same thing in pure C/scalar assembly is 600+. If you're porting a video codec inner loop to M-profile, this is the instruction that decides whether the project is feasible.

Treats `Rn` and `Rm` as four unsigned bytes each, computes `|n[i] - m[i]|` per lane, and sums all four absolute differences into `Rd`.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR; not SP, not PC |
| `<Rn>` | first packed-byte source | R0–R12, LR |
| `<Rm>` | second packed-byte source | R0–R12, LR |

The maximum result is `4 × 255 = 1020`, so it always fits in 16 bits — no overflow concern.

## Operation (pseudocode)

```text
if ConditionPassed() then
    absdiff0 = Abs(UInt(Rn<7:0>)   - UInt(Rm<7:0>))
    absdiff1 = Abs(UInt(Rn<15:8>)  - UInt(Rm<15:8>))
    absdiff2 = Abs(UInt(Rn<23:16>) - UInt(Rm<23:16>))
    absdiff3 = Abs(UInt(Rn<31:24>) - UInt(Rm<31:24>))
    Rd = absdiff0 + absdiff1 + absdiff2 + absdiff3
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

USAD8 never updates APSR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1111 1011 0111 Rn 1111 Rd 0000 Rm` |

There is no 16-bit Thumb encoding.

## Exceptions / faults

- (none)

## Example

### Example 1 — four-pixel SAD between two image rows

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ USAD8 demo: SAD between two 4-byte pixel runs (motion-estimation kernel)
    ldr     r0, =0x10203040     @ block A: bytes 0x40,0x30,0x20,0x10
    ldr     r1, =0x12223843     @ block B: bytes 0x43,0x38,0x22,0x12
    usad8   r2, r0, r1          @ r2 = |40-43|+|30-38|+|20-22|+|10-12|
                                @     = 3 + 8 + 2 + 2 = 15
loop:
    b   loop
```

**Walkthrough:**

1. `ldr r0, =...` / `ldr r1, =...` — load two 32-bit words holding four packed bytes each. Think of them as a 1×4 pixel row from two video frames.
2. `usad8 r2, r0, r1` — for each byte lane, take the unsigned absolute difference, then sum all four. `r2 = 15`. This single instruction replaces a four-iteration loop with subtract/abs/accumulate.

This is the workhorse of block-matching motion search: smaller SAD = better match.

### Example 2 — single-row block-match metric from memory

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Real-world shape: load one 4-pixel reference row and one 4-pixel
    @ candidate row from memory, score the match in one instruction.
    ldr     r0, =ref_row         @ pointer to reference luma row (4 bytes)
    ldr     r1, =cand_row        @ pointer to candidate row at (mvx, mvy)
    ldr     r2, [r0]             @ four reference bytes packed
    ldr     r3, [r1]             @ four candidate bytes packed
    usad8   r4, r2, r3           @ r4 = |r0-c0| + |r1-c1| + |r2-c2| + |r3-c3|
    @ r4 = 2 + 2 + 1 + 2 = 7  → small SAD = good match
loop:
    b   loop

    .balign 4
ref_row:   .byte 100, 110, 120, 130
    .balign 4
cand_row:  .byte 102, 108, 121, 128
```

**Walkthrough:**

1. The two `LDR`s pull a 4-byte pixel row from each frame in one memory access apiece — packed-byte layout matches what `USAD8` expects natively.
2. `usad8 r4, r2, r3` does four `|a-b|` and three adds in a single cycle. In C this would be `for (int i=0;i<4;i++) sad += abs(ref[i]-cand[i]);` — ~12 cycles of subtract/branch/abs/accumulate, plus loop overhead.
3. Compare `r4` against the best-so-far across many candidate rows; the lowest SAD wins. Scale this idea to 16×16 with `USADA8` and you have the inner loop of an H.264-class motion estimator on a Cortex-M33.

## See also

- [USADA8](USADA8.md) — same op, but accumulates into a third register (running total across many blocks)
- [SADD8](SADD8.md) — signed per-byte add, sets GE flags
- [SSUB8](SSUB8.md) — signed per-byte subtract, sets GE flags

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *USAD8*.
