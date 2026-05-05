# VSEL — conditional floating-point select (single precision)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only — `.F64` form unavailable. `VSEL` is the **branch-free FP conditional move**: it picks `Sn` or `Sm` based on the APSR flags **without** disturbing them.

The encoding only allows **four** condition codes:

- `VSELGE` — N == V       (signed >=)
- `VSELGT` — Z == 0 && N == V  (signed >)
- `VSELEQ` — Z == 1
- `VSELVS` — V == 1       (overflow set; useful as "unordered" after `VCMP`)

There is no `VSELNE` / `VSELLE` / `VSELLT` — swap operands and use `VSELGE` / `VSELGT` instead. (e.g. `x < y` → `vselgt Sd, Sm, Sn`).

## Synopsis

```text
VSEL<cc>.F32 <Sd>, <Sn>, <Sm>    @ Sd = (cc) ? Sn : Sm    cc ∈ {GE, GT, EQ, VS}
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination | S0–S31 |
| `<Sn>` | "true" source | S0–S31 |
| `<Sm>` | "false" source | S0–S31 |
| `<cc>` | condition | one of `GE`, `GT`, `EQ`, `VS` |

Note: condition is **part of the mnemonic**, not an `IT`-block predicate. `VSEL` is not allowed inside an `IT` block.

## Operation (pseudocode)

```text
CheckVFPEnabled();
if ConditionHolds(cc, APSR) then Sd = Sn else Sd = Sm;
// APSR is read but not modified. FPSCR is not modified.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR is *consumed*, not produced.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `VSEL<cc>.F32 Sd, Sn, Sm` (all VFP, so 32-bit despite "T1") |

## Exceptions / faults

- UsageFault (`NOCP`) if FPU disabled.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VSEL demo: branch-free abs-greater pick:  out = (|a| >= |b|) ? a : b
    @ S0 = a, S1 = b
    vabs.f32 s2, s0          @ |a|
    vabs.f32 s3, s1          @ |b|
    vcmpe.f32 s2, s3         @ compare |a| vs |b|, set FPSCR flags
    vmrs     APSR_nzcv, fpscr @ copy FPSCR.NZCV into APSR
    vselge.f32 s4, s0, s1    @ S4 = (|a| >= |b|) ? a : b
loop:
    b   loop
```

**Walkthrough:**

1. `vabs.f32` x2 — magnitudes for the comparison.
2. `vcmpe.f32 s2, s3` — set FPSCR's NZCV (E variant signals on qNaN; use plain `vcmp` if you need quiet semantics).
3. `vmrs APSR_nzcv, fpscr` — VFP comparisons land in FPSCR; you must hoist them to APSR before `VSEL`/`Bcc` can read them.
4. `vselge.f32 s4, s0, s1` — single-cycle, branch-free pick. No flush, no mispredict.

## See also

- [VMINNM](VMINNM.md), [VMAXNM](VMAXNM.md) — NaN-aware specialised selects
- [VMRS](VMRS.md) — bridge FPSCR → APSR (essential for `VSEL` after `VCMP`)
- [VMOV](VMOV.md)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VSEL*.
