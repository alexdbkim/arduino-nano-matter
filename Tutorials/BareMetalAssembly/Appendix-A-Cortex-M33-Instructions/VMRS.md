# VMRS — move from FPU system register (FPSCR) into a core register or APSR flags

## Class & availability

- **Class:** Floating-point (system / data movement)
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None for FPSCR; some FP system regs are privileged
- **Secure-state required:** No (FPSCR is banked between security states on M33)

## Synopsis

```text
VMRS <Rt>, FPSCR              @ Rt = FPSCR
VMRS APSR_nzcv, FPSCR         @ APSR.{N,Z,C,V} = FPSCR.{N,Z,C,V}
```

Other FP system regs (`FPEXC`, `MVFR0`, `MVFR1`, `MVFR2`, `FPSID`) are also addressable but most are privileged-only on M-profile.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rt>` | destination core register | `R0`–`R12`, `LR`; not `PC`, not `SP` |
| `APSR_nzcv` | special destination | only valid with source `FPSCR` |
| source | FP system register | `FPSCR` is the common case |

## Operation (pseudocode)

```text
if Rt == APSR_nzcv:
    APSR.N = FPSCR.N; APSR.Z = FPSCR.Z
    APSR.C = FPSCR.C; APSR.V = FPSCR.V
else:
    R[t] = FPSCR
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | ✓ | – |

Flags update **only** when destination is `APSR_nzcv`. With `Rt`, APSR is untouched.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `VMRS Rt|APSR_nzcv, FPSCR` |

32-bit Thumb-2 only.

## Exceptions / faults

- UsageFault (NOCP) if the FPU is disabled.
- UsageFault if accessing a privileged FP system register from unprivileged code.

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
    @ VMRS demo: float compare, transfer FPSCR.NZCV to APSR, then branch.
    vmov.f32 s0, #1.0
    vmov.f32 s1, #2.0
    vcmp.f32 s0, s1             @ FPSCR.NZCV updated (1.0 < 2.0 -> N=1)
    vmrs     APSR_nzcv, FPSCR   @ copy FPSCR flags into APSR
    blt      less_branch        @ now plain integer cond codes work on float result
    b        done
less_branch:
    movs     r0, #1
done:
    vmrs     r1, FPSCR          @ snapshot full FPSCR into R1 (e.g. for debug)
loop:
    b   loop
```

**Walkthrough:**

1. `vmov.f32 s0,#1.0` / `s1,#2.0` — load operands.
2. `vcmp.f32 s0, s1` — sets FPSCR.{N,Z,C,V} to the IEEE comparison result. APSR is *not* updated by VCMP itself.
3. `vmrs APSR_nzcv, FPSCR` — the canonical bridge: copies the four flag bits into APSR so ordinary conditional branches (`BLT`, `BEQ`, …) work against the float comparison.
4. `blt less_branch` — taken because `1.0 < 2.0`.
5. `vmrs r1, FPSCR` — example of grabbing the *whole* register (mode bits, exception flags) for inspection or save/restore.
6. `loop: b loop` — park.

This is the part that bites people: VCMP alone does **not** update APSR. Forgetting the `VMRS APSR_nzcv, FPSCR` step leaves your branch checking stale integer flags. Treat the pair as one unit.

## See also

- [VMSR](VMSR.md) — write FPSCR from a core register
- [VCMP](VCMP.md) / [VCMPE](VCMPE.md) — what fills FPSCR.{N,Z,C,V} in the first place
- [MRS](MRS.md) — same idea but for system / special core registers

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VMRS*.
