# NOP — no operation; consume one instruction slot and do nothing

## Class & availability

- **Class:** Hint
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
NOP
```

**When you'd actually use this** — `NOP` exists for code-size padding, manual alignment of branch targets in hot loops (paired with `.balign`), and as a "don't optimize away" placeholder when you're staring at generated disassembly. It is *not* a calibrated delay: on the M33 the prefetcher may fold it out and the cycle cost is implementation-defined. If you need N cycles, use a counted loop or the DWT cycle counter; if you need an architectural barrier, use `ISB` — `NOP` provides none. The most common legitimate site is just after a `.balign` directive, soaking up the gap up to the alignment boundary.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| (none) | — | NOP takes no operands |

## Operation (pseudocode)

```text
// Architecturally a hint: implementation is free to do nothing.
// It is *guaranteed to consume an instruction slot* but may not
// even reach execute on a superscalar pipeline. It does NOT
// guarantee timing — use a delay loop or DWT for that.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags. Never touches memory or registers.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `1011 1111 0000 0000` (`BF00`) |
| T2 | 32-bit | `1111 0011 1010 1111 1000 0000 0000 0000` (`F3AF 8000`) |

## Exceptions / faults

- (none)

## Example

### Example 1 — inert padding slots

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ NOP demo: pad an instruction stream / align a branch target
    movs    r0, #1
    nop
    nop
    nop
    adds    r0, r0, #1      @ r0 = 2 — NOPs did nothing
loop:
    b   loop
```

**Walkthrough:**

1. `movs r0, #1` — seed `r0` so we can prove the NOPs leave it alone.
2. `nop` ×3 — three slots consumed, zero state changed.
3. `adds r0, r0, #1` — `r0` becomes `2`, confirming the NOPs are inert.

This is the part that bites people: `NOP` is **not** a calibrated delay. The CPU may fold it out, fetch it in parallel, or skip it entirely. If you need N cycles, count cycles or use the DWT cycle counter.

### Example 2 — branch-target alignment for a hot loop

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Force a 4-byte alignment of a hot-loop entry; NOP absorbs the gap
    movs    r0, #10
    nop                             @ pad before the .balign
    .balign 4
hot_loop:
    subs    r0, r0, #1
    bne     hot_loop
loop:
    b   loop
```

**Walkthrough:**

1. `movs r0, #10` — loop counter.
2. `nop` — explicit 16-bit pad. Combined with `.balign 4` on the next line, it guarantees `hot_loop` lands on a 4-byte boundary so the prefetcher fetches a full 32-bit aligned line on entry.
3. `subs`/`bne` — the hot loop body itself. Aligned branch targets historically helped some Cortex-M cores fetch one fewer bus cycle; on M33 the win is modest but the pattern is harmless and standard.

## See also

- [YIELD](YIELD.md) — hint that this thread is spinning
- [WFI](WFI.md) — sleep instead of spinning
- [ISB](ISB.md) — when you need a real architectural barrier, not a NOP

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.100 — *NOP*.
