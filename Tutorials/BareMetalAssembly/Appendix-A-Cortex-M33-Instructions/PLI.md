# PLI — preload instructions; hint that a code address will be executed soon

## Class & availability

- **Class:** Hint
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅ (executes as NOP)
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
PLI  [<Rn>{, #<imm>}]
PLI  [<Rn>, <Rm>{, LSL #<shift>}]
PLI  <label>                   @ PC-relative literal form
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rn>` | base GPR | `R0`–`R12`, `SP`, `PC` (literal form) |
| `<imm>` | offset | `-255..+4095` |
| `<Rm>` | index GPR | `R0`–`R12`; optional `LSL #0..3` |

## Operation (pseudocode)

```text
// Hint that the line containing the address will be executed.
// On a core with an instruction cache, PLI can pull the line in
// before the actual fetch, hiding miss latency. The Cortex-M33
// in the EFR32MG24 has no programmer-visible I-cache (the chip
// uses a flash prefetcher and an internal cache that is not
// architecturally exposed), so PLI executes as a NOP.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1111 1001 1001 nnnn 1111 iiii iiii iiii` — immediate `[Rn, #imm12]` |
| T2 | 32-bit | `1111 1001 0001 nnnn 1111 1100 iiii iiii` — immediate `[Rn, #-imm8]` |
| T3 | 32-bit | `1111 1001 0001 nnnn 1111 0000 00ss mmmm` — register `[Rn, Rm, LSL #s]` |

No 16-bit form.

## Exceptions / faults

- (none). Fault-free.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ About to call a cold function — hint its prologue first
    ldr     r0, =cold_path
    pli     [r0]                @ hint "we're about to execute here"
    pli     [r0, #32]           @ next line ahead
    blx     r0                  @ now actually call it
loop:
    b   loop

    .thumb_func
cold_path:
    movs    r1, #1
    movs    r2, #2
    adds    r0, r1, r2
    bx      lr
```

**Walkthrough:**

1. `pli [r0]` — would warm the I-cache line containing `cold_path` on cores that have one. NOP here.
2. `blx r0` — the actual indirect call. On the Nano Matter the flash prefetcher handles this transparently anyway.

`PLI` is essentially documentation on this chip. Keep it in code that's also targeted at Cortex-A or M7; drop it if the codebase is M33-only and you want minimum image size — every `PLI` is a 4-byte NOP.

## See also

- [PLD](PLD.md) — data-read hint
- [PLDW](PLDW.md) — data-write hint
- [NOP](NOP.md) — what PLI becomes on this chip

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.118 — *PLI*.
