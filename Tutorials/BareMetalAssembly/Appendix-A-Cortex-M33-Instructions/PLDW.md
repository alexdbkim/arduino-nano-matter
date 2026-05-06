# PLDW — preload data for write (NOT available on Armv8-M)

## Class & availability

- **Class:** Hint
- **Architecture:** Armv7-A / Armv7-R **Multiprocessing Extension only**. Not part of Armv8-M.
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ❌ — the encoding is **UNDEFINED** on this core. `arm-none-eabi-as -mcpu=cortex-m33 -mthumb` rejects it.
- **Privilege required:** N/A
- **Secure-state required:** N/A

## Synopsis

```text
PLDW [<Rn>{, #<imm>}]      @ Armv7-A only — do NOT emit on Cortex-M33
```

**When you'd actually use this** — you wouldn't, on Cortex-M33. `PLDW` is an Armv7-A multiprocessing-extension hint for upcoming *writes* to a shared cache line, and Armv8-M never adopted it. The mnemonic appears in this reference purely so that when you're porting Cortex-A DSP source to the Nano Matter and the assembler rejects `pldw`, you know what to substitute (a `NOP`, or just delete it). On M33 there's no D-cache to coordinate, so the hint has nothing to optimise even if it were encodable — gate it behind `#ifdef __ARM_ARCH_8M_MAIN__` in portable code.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| (n/a on M33) | — | The mnemonic is documented here only because it appears in shared headers / portable code |

## Operation (pseudocode)

```text
// On a multiprocessing-capable Cortex-A core: hint that the line
// at the address will be written soon, so it can be brought into
// the cache in writable state.
//
// On Cortex-M33 this encoding is not allocated. Executing it is
// UNPREDICTABLE; the ARMv8-M ARM does not list PLDW. Most
// assemblers reject it for this target.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

(Not applicable — instruction is not implemented.)

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| (none on Armv8-M) | — | The Armv7-A encoding `1111 1000 1011 nnnn 1111 iiii iiii iiii` is not defined for Armv8-M Thumb. |

## Exceptions / faults

- If somehow emitted as raw bytes on a Cortex-M33, the result is implementation-defined and may take a UsageFault (`UNDEFINSTR`).

## Example

Because `PLDW` is not encodable for Cortex-M33, there is no compilable example. If you have portable code that uses it, gate it behind an architecture macro and substitute `NOP` (or just nothing) on Armv8-M targets:

### Example 1 — Portable shim that compiles on M33

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Portable shim: where Armv7-A would PLDW, M33 just does nothing.
    @ #ifdef __ARM_ARCH_8M_MAIN__
    nop                         @ stand-in for PLDW [r0]
    @ #else
    @     pldw    [r0]
    @ #endif
    movs    r0, #0
loop:
    b   loop
```

**Walkthrough:**

1. `nop` — placeholder where an Armv7-A build would emit `pldw`. Compiles cleanly on M33.
2. `movs r0, #0` — proves we successfully assembled past the shim.

This is the part that bites people: third-party DSP/RTOS sources written for Cortex-A sometimes sprinkle `PLDW` into hot loops. When you retarget to the Nano Matter you'll get a hard assembler error — strip them, or wrap them in `#ifdef`.

### Example 2 — Macro shim wrapping a write hint

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    ldr     r0, =shared
    @ PLDW_SHIM macro: pldw [r0] on Armv7-A, nop on Armv8-M.
    nop                         @ <-- where pldw [r0] would live
    movs    r1, #1
    str     r1, [r0]            @ the real write the hint advertised
loop:
    b   loop

    .data
    .align 2
shared: .word 0
```

**Walkthrough:**

1. `nop` — the M33-side substitute. A header decides via `#if __ARM_ARCH_PROFILE == 'A'` whether to emit `pldw [r0]` here or this NOP.
2. `str r1, [r0]` — the actual write the hint was advertising. Correctness doesn't depend on the hint either way.
3. Keeping the shim avoids two divergent versions of the source — the M33 build assembles cleanly and the Cortex-A build still gets its prefetch.

## See also

- [PLD](PLD.md) — actually available on Cortex-M33 (executes as NOP)
- [PLI](PLI.md) — instruction-side preload, available
- [NOP](NOP.md) — the safe substitute on this chip

## Reference

- *Arm®v7-A/R Architecture Reference Manual* (DDI 0406C), §A8.8.127 — *PLD, PLDW (immediate)* (Armv7 MP extension; **not** carried into Armv8-M).
- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.116 — only `PLD`/`PLI` are listed; `PLDW` is absent.
