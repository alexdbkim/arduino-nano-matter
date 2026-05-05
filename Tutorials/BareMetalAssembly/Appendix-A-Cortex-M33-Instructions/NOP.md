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

## See also

- [YIELD](YIELD.md) — hint that this thread is spinning
- [WFI](WFI.md) — sleep instead of spinning
- [ISB](ISB.md) — when you need a real architectural barrier, not a NOP

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.100 — *NOP*.
