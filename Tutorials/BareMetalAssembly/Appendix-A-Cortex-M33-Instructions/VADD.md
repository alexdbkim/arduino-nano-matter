# VADD — floating-point add (single precision)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

The EFR32MG24 implements **FPv5-SP** (single precision only). The `.F64` form of this instruction does **not** exist on this part — use `.F32` only.

## Synopsis

```text
VADD.F32 <Sd>, <Sn>, <Sm>
```

**When you'd actually use this** is the bread and butter of any embedded control loop with non-trivial physics: accumulating the integral term in a PID (`integ += err*dt`), summing per-axis products in an acceleration-magnitude pre-norm, or running a complementary filter such as `angle = a*gyro + (1−a)*accel`. Each `VADD` performs one IEEE rounding; if you're chaining `a + b*c`, prefer `VFMA` for one combined rounding instead of two. The biggest gotcha for newcomers isn't accuracy, though — it's that without `CPACR.CP10/CP11 = 0b11` enabling the FPU, the very first `vadd.f32` raises a `NOCP` UsageFault before it computes anything.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination single-precision register | S0–S31 |
| `<Sn>` | first source single-precision register | S0–S31 |
| `<Sm>` | second source single-precision register | S0–S31 |

## Operation (pseudocode)

```text
CheckVFPEnabled();
Sd = FPAdd(Sn, Sm, FPSCR);   // IEEE-754 round-to-nearest-even by default
// FPSCR cumulative exception bits (IOC, DZC, OFC, UFC, IXC, IDC) may set.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR is untouched. IEEE exceptions accumulate in `FPSCR` (read with `VMRS`).

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VADD.F32 Sd, Sn, Sm` (no T1, all VFP ops are 32-bit) |

## Exceptions / faults

- UsageFault (`NOCP`) if FPU is not enabled (`CPACR.CP10/CP11 ≠ 0b11`).
- No memory access — no alignment fault possible.

## Example

### Example 1 — sum three floats already in S0..S2

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VADD demo: sum three floats already loaded into S0..S2
    vadd.f32 s3, s0, s1     @ S3 = S0 + S1
    vadd.f32 s3, s3, s2     @ S3 = S3 + S2  (running total)
    vmov     r0, s3         @ move bit-pattern into r0 for inspection
loop:
    b   loop
```

**Walkthrough:**

1. `vadd.f32 s3, s0, s1` — first partial sum, single IEEE round.
2. `vadd.f32 s3, s3, s2` — accumulate the third term; each `VADD` rounds independently (if you need a single rounding for `a+b*c`, use `VFMA`).
3. `vmov r0, s3` — bit-copy the float into a core register so a debugger can inspect it.

### Example 2 — one PID step (proportional + integral update)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VADD demo 2: out = Kp*err + integ ;  integ += Ki*dt*err
    @ S0=err, S1=Kp, S2=Ki*dt, S3=integ, S4=out (result)
    vmul.f32 s4, s1, s0      @ S4 = Kp * err
    vadd.f32 s4, s4, s3      @ S4 = Kp*err + integ   (= controller output)
    vmul.f32 s5, s2, s0      @ S5 = Ki*dt * err
    vadd.f32 s3, s3, s5      @ integ += Ki*dt*err     (state update)
loop:
    b   loop
```

**Walkthrough:**

1. `vmul.f32` then `vadd.f32` form the proportional-plus-integral output — two roundings, but each term lives in a separate register so the debugger can watch them.
2. The second `VMUL`/`VADD` pair updates the integrator state for the next tick. Because `VADD` doesn't touch APSR, you can interleave it with integer scheduling logic without disturbing condition flags.
3. If you cared about the extra rounding, `vfma.f32 s4, s1, s0` (Sd += Sn*Sm) would replace the first two instructions with a single fused multiply-add.

## See also

- [VSUB](VSUB.md) — same shape, subtraction
- [VMLA](VMLA.md) — multiply-then-add (two roundings)
- [VFMA](VFMA.md) — fused multiply-add (single rounding)
- [VMRS](VMRS.md) — read FPSCR exception bits
- [VMOV](VMOV.md) — transfer between S-reg and core reg

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VADD (floating-point)*.
