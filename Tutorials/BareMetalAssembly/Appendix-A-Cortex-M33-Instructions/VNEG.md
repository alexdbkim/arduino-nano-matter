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

## See also

- [VABS](VABS.md) — clear (don't flip) the sign bit
- [VNMUL](VNMUL.md) — negate the result of a multiply
- [VSUB](VSUB.md)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VNEG (floating-point)*.
