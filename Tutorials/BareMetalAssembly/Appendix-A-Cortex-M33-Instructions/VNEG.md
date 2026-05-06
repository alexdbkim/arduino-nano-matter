# VNEG — floating-point negate (single precision)

## Class & availability

- **Class:** Floating-point
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

FPv5-SP only. `.F64` form unavailable.

## Synopsis

```text
VNEG.F32 <Sd>, <Sm>            @ Sd = -Sm  (sign bit flipped)
```

**When you'd actually use this** is whenever you need `−x` cheaply — flipping the sign of an FIR/IIR coefficient that's stored positive, negating a velocity to invert a motor command, or pre-negating a term so you can use `VADD` instead of `VSUB` in a tight loop. Like `VABS`, it's a single sign-bit toggle (one cycle, never traps on NaN). If a `VNEG` is followed immediately by a multiply, prefer `VNMUL` — it fuses the negate with the multiply for free. The CPACR rule still bites first: enable `CP10/CP11` before executing any V-instruction or you'll HardFault out of the gate.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | destination | S0–S31 |
| `<Sm>` | source | S0–S31 |

## Operation (pseudocode)

```text
CheckVFPEnabled();
Sd = Sm with sign bit toggled;   // bitwise: Sd = Sm ^ 0x80000000
// NaNs pass through with sign flipped. No FPSCR exception bits set.
```

Like `VABS`, this is a pure bit-flip, not a numerical negation, so it never signals on NaN.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

APSR untouched. FPSCR untouched.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 | 32-bit | `VNEG.F32 Sd, Sm` |

## Exceptions / faults

- UsageFault (`NOCP`) if FPU disabled.

## Example

### Example 1 — `acc -= x` via negate-then-add

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VNEG demo: y = -x (then accumulate)
    @ S0 = x, S1 = acc
    vneg.f32 s2, s0          @ S2 = -x
    vadd.f32 s1, s1, s2      @ acc += -x   (i.e. acc -= x)
loop:
    b   loop
```

**Walkthrough:**

1. `vneg.f32 s2, s0` — toggle sign in one cycle.
2. `vadd.f32 s1, s1, s2` — fold negated value into accumulator. If you're doing this often, prefer `VFMS`/`VNMUL` to fuse the negate.

### Example 2 — flip the sign of a stored-positive IIR feedback coefficient

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VNEG demo 2: y[n] += -a1 * y[n-1]   (a1 stored positive in tables)
    @ S0 = a1 (positive),  S1 = y[n-1],  S2 = y[n] accumulator
    vneg.f32 s3, s0          @ S3 = -a1
    vmul.f32 s4, s3, s1      @ S4 = -a1 * y[n-1]
    vadd.f32 s2, s2, s4      @ y[n] += -a1 * y[n-1]
loop:
    b   loop
```

**Walkthrough:**

1. `vneg.f32 s3, s0` — one-cycle sign flip; the original positive `a1` in `S0` is preserved for any other tap that needs it.
2. `vmul.f32` then `vadd.f32` complete the IIR feedback term.
3. The whole sequence collapses to a single `vfms.f32 s2, s0, s1` (Sd −= Sn*Sm) if you want one rounding and one cycle — but that loses the explicit `−a1` value, which the example keeps visible for clarity.

## See also

- [VABS](VABS.md) — clear (don't flip) the sign bit
- [VNMUL](VNMUL.md) — negate the result of a multiply
- [VSUB](VSUB.md)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VNEG (floating-point)*.
