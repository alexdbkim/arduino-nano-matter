# VSUB — floating-point subtract (single precision)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only. `.F64` is **not** available on this MCU; emit `.F32`.

## Synopsis

```text
VSUB.F32 <Sd>, <Sn>, <Sm>
```

**When you'd actually use this** is everywhere you need a *difference*: the PID error term `error = setpoint − measured`, the sample-to-sample delta in a derivative term, or the per-axis offset before squaring in a Euclidean distance. Like `VADD`, it's one rounded IEEE op per instruction. Doing the same with integer math (cast → subtract → recast) loses precision and costs more cycles than just letting the FPU do it — *provided* you remembered to set `CPACR.CP10/CP11 = 0b11`. That CPACR step is the #1 reason a "trivial" floating-point routine HardFaults the first time it runs on a fresh M33.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination single-precision register | S0–S31 |
| `<Sn>` | minuend | S0–S31 |
| `<Sm>` | subtrahend | S0–S31 |

## Operation (pseudocode)

```text
CheckVFPEnabled();
Sd = FPSub(Sn, Sm, FPSCR);   // i.e. Sn - Sm with IEEE rounding
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR is untouched. IEEE exception bits accumulate in `FPSCR`.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VSUB.F32 Sd, Sn, Sm` |

## Exceptions / faults

- UsageFault (`NOCP`) if FPU is disabled.
- No memory access.

## Example

### Example 1 — 1-D distance `|x1 − x0|`

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VSUB demo: 1-D distance |x1 - x0|
    vsub.f32 s2, s1, s0      @ S2 = x1 - x0  (signed)
    vabs.f32 s2, s2          @ S2 = |S2|
loop:
    b   loop
```

**Walkthrough:**

1. `vsub.f32 s2, s1, s0` — straightforward subtraction; sign of result encodes which is larger.
2. `vabs.f32 s2, s2` — strip the sign bit so `S2` is the unsigned distance.

### Example 2 — PID error and proportional term

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VSUB demo 2: err = setpoint - measured ;  u = Kp * err
    @ S0=setpoint, S1=measured, S2=Kp ; results in S3 (err) and S4 (u)
    vsub.f32 s3, s0, s1      @ S3 = setpoint - measured = err
    vmul.f32 s4, s3, s2      @ S4 = Kp * err
    vabs.f32 s5, s3          @ S5 = |err|  (handy for deadband checks)
loop:
    b   loop
```

**Walkthrough:**

1. `vsub.f32 s3, s0, s1` — operand order is `Sd = Sn − Sm`, so `setpoint` goes in `Sn`. Sign of the result tells you whether the plant is above or below target.
2. `vmul.f32 s4, s3, s2` — apply the proportional gain. A second `VSUB` would let you subtract the previous `err` for the derivative term in a full PID.
3. `vabs.f32 s5, s3` — many controllers gate the integral term when `|err|` is below a deadband; computing it here costs one cycle.

## See also

- [VADD](VADD.md) — companion add
- [VABS](VABS.md) — strip sign for distance
- [VFMS](VFMS.md) — fused subtract-and-multiply
- [VMRS](VMRS.md)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VSUB (floating-point)*.
