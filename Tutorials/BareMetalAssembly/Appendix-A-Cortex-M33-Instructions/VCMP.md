# VCMP — compare two single-precision floats and update FPSCR flags (quiet on QNaN)

## Class & availability

- **Class:** Floating-point (compare)
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
VCMP.F32  <Sd>, <Sm>          @ Sd vs Sm
VCMP.F32  <Sd>, #0.0          @ Sd vs +0.0 (immediate form, only #0.0 is legal)
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | first single | `S0`–`S31` |
| `<Sm>` | second single | `S0`–`S31` |
| `#0.0` | immediate | only `0.0` (positive zero) is encodable |

## Operation (pseudocode)

```text
result = FPCompare(Sd, Sm, signal_NaN=False)
FPSCR.{N,Z,C,V} = result        @ ARM IEEE flag mapping below
```

ARM IEEE → NZCV mapping:

| Relation        | N | Z | C | V |
|-----------------|---|---|---|---|
| Equal           | 0 | 1 | 1 | 0 |
| Less than       | 1 | 0 | 0 | 0 |
| Greater than    | 0 | 0 | 1 | 0 |
| Unordered (NaN) | 0 | 0 | 1 | 1 |

VCMP **does not signal** on quiet NaN inputs (it raises Invalid Operation only on a *signaling* NaN, and even then only via the cumulative `IOC` exception flag — the variant that *also* signals on QNaN is `VCMPE`).

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | ✓ | – |

Updates **FPSCR** flags, not APSR. Use `VMRS APSR_nzcv, FPSCR` to bridge before a conditional branch.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 (register)  | 32-bit | `VCMP.F32 Sd, Sm` |
| T2 (immediate) | 32-bit | `VCMP.F32 Sd, #0.0` |

32-bit Thumb-2 only.

## Exceptions / faults

- UsageFault (NOCP) if the FPU is disabled.
- Sets `FPSCR.IOC` if either operand is a signaling NaN; trap-enable bits in FPSCR are RAZ/WI on FPv5 (no traps, only sticky flags).

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
    @ VCMP demo: branch on (a > 0.0) using the canonical FPSCR -> APSR bridge.
    vmov.f32 s0, #-1.5
    vcmp.f32 s0, #0.0           @ compare directly against zero (immediate form)
    vmrs     APSR_nzcv, FPSCR   @ copy NZCV into APSR for cond branch
    bgt      positive
    movs     r0, #0              @ s0 <= 0
    b        done
positive:
    movs     r0, #1
done:
loop:
    b   loop
```

**Walkthrough:**

1. `vmov.f32 s0, #-1.5` — load test value. (Note: `0.0` is *not* a valid VMOV F32 immediate — VFP's 8-bit immediate format can't encode it. But VCMP has a separate immediate encoding that *is* hard-wired to `#0.0`.)
2. `vcmp.f32 s0, #0.0` — `-1.5 < 0.0` → FPSCR flags `N=1, Z=0, C=0, V=0`.
3. `vmrs APSR_nzcv, FPSCR` — bridge: APSR now holds those same NZCV bits.
4. `bgt positive` — not taken (because LT, not GT). `R0` is set to 0.
5. `loop: b loop` — park.

This is the part that bites people: VCMP updates **FPSCR**, not APSR. Without the VMRS, your branch is testing leftover integer flags from whatever ran before. Always `VCMP` → `VMRS APSR_nzcv, FPSCR` → conditional branch, in that order, with no integer flag-setting instructions in between.

## See also

- [VCMPE](VCMPE.md) — same, but raises Invalid Operation on QNaNs too
- [VMRS](VMRS.md) — moves FPSCR.NZCV into APSR
- [CMP](CMP.md) — integer comparison

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VCMP*.
