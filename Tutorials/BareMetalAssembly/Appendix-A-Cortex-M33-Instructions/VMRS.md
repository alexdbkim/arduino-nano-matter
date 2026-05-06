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

**When you'd actually use this** — VMRS reads FPSCR. Two main jobs: (1) the canonical `VMRS APSR_nzcv, FPSCR` bridge after `VCMP`/`VCMPE`, so a normal `BLT`/`BEQ` can branch on the float comparison; (2) reading the sticky exception bits (`IXC` inexact, `OFC` overflow, `UFC` underflow, `IOC` invalid, `DZC` divide-by-zero) after a numerical sequence to detect rounding loss or bad inputs — useful in safety-critical code that validates every operation, and the only way to inspect those bits since FPv5-SP doesn't take real exceptions on them.

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

### Example 1 — FPSCR→APSR bridge for `BLT`

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

### Example 2 — check FPSCR.IXC after a `1/3` division

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VMRS demo 2: detect inexact rounding via FPSCR.IXC after an exact divide.
    vmov.f32 s0, #1.0
    vmov.f32 s1, #3.0
    vdiv.f32 s2, s0, s1           @ 1/3 -> result rounded -> FPSCR.IXC = 1
    vmrs     r0, FPSCR            @ R0 = full FPSCR
    ubfx     r1, r0, #4, #1       @ R1 = FPSCR.IXC (bit 4)
    cbz      r1, exact            @ R1 == 0 -> result was exact
    movs     r2, #1                @ inexact path: take corrective action
    b        done
exact:
    movs     r2, #0
done:
loop:
    b   loop
```

**Walkthrough:**

1. `vdiv.f32 s2, s0, s1` — `1.0 / 3.0` cannot be represented exactly in `f32`, so the FPU rounds and sets `FPSCR.IXC` (Inexact, bit 4) sticky.
2. `vmrs r0, FPSCR` — pull the *whole* FPSCR (we want bit 4, not just NZCV).
3. `ubfx r1, r0, #4, #1` — extract a single bit cleanly. Equivalent to `(r0 >> 4) & 1`.
4. `cbz r1, exact` — branch if the inexact bit was clear. (CBZ is a 16-bit Thumb-2 compare-and-branch-if-zero.)
5. The inexact path could log, retry in higher precision, or refuse to use the result — depending on the application's tolerance.
6. `loop: b loop` — park.

Note: IXC is **sticky**. To probe a single op, clear FPSCR with `VMSR` first, run the op, then `VMRS` and test. Otherwise a leftover `1` from earlier code will mislead you.

## See also

- [VMSR](VMSR.md) — write FPSCR from a core register
- [VCMP](VCMP.md) / [VCMPE](VCMPE.md) — what fills FPSCR.{N,Z,C,V} in the first place
- [MRS](MRS.md) — same idea but for system / special core registers

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VMRS*.
