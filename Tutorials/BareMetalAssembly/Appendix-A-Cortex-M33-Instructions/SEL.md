# SEL — select bytes from Rn or Rm based on APSR.GE flags

## Class & availability

- **Class:** DSP-SIMD
- **Architecture:** ARMv8-M Mainline + DSP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
SEL  <Rd>, <Rn>, <Rm>
```

Per byte lane, copy the byte from `Rn` if the corresponding `APSR.GE` bit is set, otherwise copy the byte from `Rm`. Four 1-bit GE flags, four byte lanes — they line up exactly. This is the second half of every "compare-then-blend" pattern in DSP code.

**When you'd actually use this** — `SEL` only ever follows a parallel-add/sub that set the GE flags (`SADD8`, `SSUB8`, `SADD16`, `SSUB16`, and unsigned variants). The pair lets you do per-lane min, max, clamp, or conditional blend in two instructions — the building block of saturating SIMD code, vector compare-and-pick, and the per-byte "pick whichever sample passed the threshold" patterns inside small DSP routines. The scalar alternative is a per-lane unpack-compare-pack loop; `SADD8`+`SEL` flattens that into 2 cycles of work for 4 lanes.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR |
| `<Rn>` | source whose bytes are picked when GE = 1 | R0–R12, LR |
| `<Rm>` | source whose bytes are picked when GE = 0 | R0–R12, LR |

GE flags are typically set by the parallel-add/subtract instructions: `SADD8`, `SSUB8`, `SADD16`, `SSUB16`, `UADD8`, `USUB8`, `UADD16`, `USUB16`, etc. They are *not* set by `ADD`, `SUB`, or by `S`-suffixed scalar ops — those touch N/Z/C/V instead.

## Operation (pseudocode)

```text
if ConditionPassed() then
    Rd<7:0>   = if APSR.GE<0> == '1' then Rn<7:0>   else Rm<7:0>
    Rd<15:8>  = if APSR.GE<1> == '1' then Rn<15:8>  else Rm<15:8>
    Rd<23:16> = if APSR.GE<2> == '1' then Rn<23:16> else Rm<23:16>
    Rd<31:24> = if APSR.GE<3> == '1' then Rn<31:24> else Rm<31:24>
```

For 16-bit SIMD ops (`SADD16` / `SSUB16` / …), the GE flags come in pairs: GE[1:0] for the low halfword, GE[3:2] for the high halfword. Each pair is set together, so `SEL` still does the right thing per halfword.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

`SEL` reads `APSR.GE` and writes nothing.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1111 1010 1010 Rn 1111 Rd 1000 Rm` |

32-bit only.

## Exceptions / faults

- (none)

## Example

### Example 1 — per-byte signed `max(a, b)` via `SSUB8` + `SEL`

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ SEL demo: per-byte signed max(a, b) using SSUB8 + SEL
    @ For each lane: GE=1 iff (a - b) >= 0, i.e. a >= b. SEL then picks a where GE=1, else b.
    ldr     r0, =0x7F01F010     @ a: bytes 0x10, 0xF0(-16), 0x01,  0x7F(+127)
    ldr     r1, =0x80020A20     @ b: bytes 0x20, 0x0A(+10), 0x02,  0x80(-128)
    ssub8   r2, r0, r1          @ per-byte (a - b); sets APSR.GE<3:0> = signs of results
    sel     r3, r0, r1          @ r3 = per-lane max(a, b) under signed compare
    @ Lane 0: 0x10 - 0x20 = neg → GE0=0 → pick b=0x20
    @ Lane 1: 0xF0(-16) - 0x0A(+10) = -26 → GE1=0 → pick b=0x0A
    @ Lane 2: 0x01 - 0x02 = -1 → GE2=0 → pick b=0x02
    @ Lane 3: 0x7F - 0x80(-128) = +255 wraps but signed compare gives a>=b → GE3=1 → pick a=0x7F
    @ r3 = 0x7F02_0A20
loop:
    b   loop
```

**Walkthrough:**

1. `ssub8 r2, r0, r1` — subtracts `r1` from `r0` lane-by-lane. We don't actually care about the differences in `r2`; the side effect is what matters: each `APSR.GE<i>` is set iff lane `i` of the signed difference is `>= 0`, i.e. `a[i] >= b[i]`.
2. `sel r3, r0, r1` — for each lane, GE=1 → take from `r0` (the larger byte), GE=0 → take from `r1`. The result is the lane-wise signed maximum.

That `SADD8`/`SSUB8` (or unsigned variants) → `SEL` is **the** GE-flag pattern. Min, max, clamp, conditional blend — they all collapse to two instructions.

### Example 2 — per-byte unsigned `min(a, b)` via `USUB8` + `SEL`

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Per-byte unsigned min(a, b): USUB8 sets APSR.GE<i> = 1 when the
    @ unsigned subtract a[i] - b[i] did NOT borrow, i.e. when a[i] >= b[i].
    @ So to keep the smaller byte we tell SEL "if GE=1 take b, else take a".
    ldr     r0, =0x10203040     @ a: bytes 0x40, 0x30, 0x20, 0x10
    ldr     r1, =0x05FF1050     @ b: bytes 0x50, 0x10, 0xFF, 0x05
    usub8   r2, r0, r1          @ updates APSR.GE<3:0>; r2 itself is discarded
    sel     r3, r1, r0          @ per-lane: GE=1 -> b (the smaller), GE=0 -> a
    @ Lane 0: a=0x40 vs b=0x50 -> a<b -> GE0=0 -> pick a=0x40
    @ Lane 1: a=0x30 vs b=0x10 -> a>=b -> GE1=1 -> pick b=0x10
    @ Lane 2: a=0x20 vs b=0xFF -> a<b -> GE2=0 -> pick a=0x20
    @ Lane 3: a=0x10 vs b=0x05 -> a>=b -> GE3=1 -> pick b=0x05
    @ r3 = 0x05201040 — the per-lane unsigned min
loop:
    b   loop
```

**Walkthrough:**

1. `usub8 r2, r0, r1` — does four parallel unsigned subtracts. The numerical result in `r2` doesn't matter; we only care about the side effect: `APSR.GE<i>` is `1` precisely when `a[i] >= b[i]`.
2. `sel r3, r1, r0` — for each lane GE=1 picks `b` (the smaller byte when `a >= b`), GE=0 picks `a`. Swap the operand order vs. the max example and the same two-instruction skeleton flips between min and max.

## See also

- [SADD8](SADD8.md) — signed per-byte add, sets GE flags
- [SSUB8](SSUB8.md) — signed per-byte sub, the natural compare-feeder for `SEL`
- [UADD8](UADD8.md) / [USUB8](USUB8.md) — unsigned variants
- [SADD16](SADD16.md) — halfword form (GE flags come in pairs)
- [MSR](MSR.md) — write APSR.GE directly if you want to drive `SEL` manually

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *SEL*.
