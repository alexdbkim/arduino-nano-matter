# VLDR — load a single-precision float from memory into an FPU register

## Class & availability

- **Class:** Floating-point (data movement)
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
VLDR.32 <Sd>, [<Rn>{, #±<imm>}]   @ register + immediate offset
VLDR.32 <Sd>, <label>             @ PC-relative (assembler builds a literal pool)
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | single-precision FPU register | `S0`–`S31` |
| `<Rn>` | base core register | any of `R0`–`R12`, `SP`, or `PC` |
| `#<imm>` | immediate offset | multiple of 4, range `-1020 … +1020` |
| `<label>` | PC-relative label | resolved by assembler; loaded via literal pool |

The size suffix is `.32` (alias `.F32`); there is no half-word VLDR on Cortex-M33's FPv5-SP.

## Operation (pseudocode)

```text
addr = (Rn == PC ? Align(PC,4) : Rn) + (add ? imm : -imm)
Sd   = MemA[addr, 4]            @ must be 4-byte aligned
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

VLDR never updates APSR or FPSCR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `VLDR.32 Sd, [Rn, #±imm]` (imm = 4·u8) |

VLDR is 32-bit Thumb-2 only — no 16-bit encoding, no writeback form (use VLDM for that).

## Exceptions / faults

- UsageFault (NOCP) if the FPU is disabled.
- UsageFault on unaligned address (single loads must be 4-byte aligned).
- BusFault / MemManage on inaccessible memory.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VLDR demo: pull a constant from the literal pool, then index into an array.
    ldr     r0, =coeffs         @ R0 -> base of coeffs[]
    vldr.32 s0, [r0]            @ S0 = coeffs[0]
    vldr.32 s1, [r0, #4]        @ S1 = coeffs[1]
    vldr.32 s2, [r0, #8]        @ S2 = coeffs[2]
    vldr.32 s3, pi              @ S3 = pi via PC-relative literal
loop:
    b   loop

    .align 2
coeffs:
    .float 1.0, 2.0, 3.0
pi:
    .float 3.1415927
```

**Walkthrough:**

1. `ldr r0, =coeffs` — classical core-side trick: assembler stuffs the address of `coeffs` into a literal pool and emits a PC-relative `LDR`.
2. `vldr.32 s0, [r0]` — 4 bytes at `[R0]` go straight into `S0`. No int→float; the bytes *are* an `f32`.
3. `vldr.32 s1, [r0, #4]` — same, +4 bytes. Note offsets must be multiples of 4.
4. `vldr.32 s3, pi` — assembler emits a PC-relative form. The CPU computes `Align(PC,4) + offset`, fetches one word, drops it in `S3`.
5. `loop: b loop` — park.

This is the part that bites people: the immediate offset must be a multiple of 4 in `±1020`. Larger or unaligned offsets force you to materialise the address in a core register first.

## See also

- [VSTR](VSTR.md) — the store counterpart
- [VLDM](VLDM.md) — load multiple registers in one shot
- [VPOP](VPOP.md) — VLDM specialised for the stack
- [LDR](LDR.md) — core-register load

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VLDR*.
