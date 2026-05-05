# PLD — preload data; hint that a data address will be read soon

## Class & availability

- **Class:** Hint
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅ (executes as NOP)
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
PLD  [<Rn>{, #<imm>}]
PLD  [<Rn>, <Rm>{, LSL #<shift>}]
PLD  <label>                   @ PC-relative literal form
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rn>` | base GPR | `R0`–`R12`, `SP`, `PC` (literal form). Not `LR`. |
| `<imm>` | offset | `-255..+4095` depending on encoding |
| `<Rm>` | index GPR | `R0`–`R12`; optional `LSL #0..3` |

## Operation (pseudocode)

```text
// Architecturally a hint to load the cache line containing the
// computed address into the data cache. Free to be ignored.
// The Cortex-M33 in the EFR32MG24 has no architecturally
// programmer-visible D-cache, so PLD executes as a NOP. The
// instruction is still useful if the same source is later compiled
// for an M7 or A-class core; on this chip it is harmless padding.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags. Never raises a fault, even if the hinted address is unmapped.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1111 1000 1001 nnnn 1111 iiii iiii iiii` — immediate, `[Rn, #imm12]` |
| T2 | 32-bit | `1111 1000 0001 nnnn 1111 1100 iiii iiii` — immediate, `[Rn, #-imm8]` |
| T3 | 32-bit | `1111 1000 0001 nnnn 1111 0000 00ss mmmm` — register, `[Rn, Rm, LSL #s]` |

No 16-bit form.

## Exceptions / faults

- (none). PLD is fault-free by definition; it never signals a precise abort even on a bad address.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Hint that the upcoming buffer read should be cached if possible
    ldr     r0, =g_buf
    pld     [r0]                @ hint the line at &g_buf[0]
    pld     [r0, #32]           @ and the next 32 bytes ahead
    ldr     r1, [r0]            @ actual read
    ldr     r2, [r0, #32]
loop:
    b   loop

    .data
    .align 5
g_buf: .skip 64
```

**Walkthrough:**

1. `pld [r0]` — on a cached core, would start a fetch into D-cache. On the Nano Matter's M33 it's a NOP.
2. `pld [r0, #32]` — second hint for the next cache line.
3. The real `ldr` reads follow. On this chip you get no speedup; on a portable codebase you do.

This is the part that bites people: don't *rely* on `PLD` for correctness. It's a hint, not an access. If you need the data in memory, issue a real load.

## See also

- [PLDW](PLDW.md) — same idea, hinting an upcoming write
- [PLI](PLI.md) — preload an instruction line
- [NOP](NOP.md) — what PLD becomes on this chip

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.116 — *PLD*.
