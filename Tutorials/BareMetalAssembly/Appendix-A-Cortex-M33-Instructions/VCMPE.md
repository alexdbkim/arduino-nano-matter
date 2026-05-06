# VCMPE — compare two single-precision floats; raise Invalid Operation on any NaN

## Class & availability

- **Class:** Floating-point (compare)
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
VCMPE.F32 <Sd>, <Sm>          @ Sd vs Sm; signals on any NaN
VCMPE.F32 <Sd>, #0.0          @ Sd vs +0.0
```

**When you'd actually use this** — VCMPE is VCMP's strict-IEEE sibling: same comparison, same NZCV mapping, but it *also* sets `FPSCR.IOC` (Invalid Operation) on **any** NaN — including quiet NaNs. Reach for it in safety-critical or numerical code where a NaN input means "your data is broken" and you want a checkable record, not a silent "unordered" result. Like VCMP, the comparison output lands in FPSCR; you still need `VMRS APSR_nzcv, FPSCR` (or `VMRS Rt, FPSCR` + `TST` for the IOC bit) before branching.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | first single | `S0`–`S31` |
| `<Sm>` | second single | `S0`–`S31` |
| `#0.0` | immediate | only `0.0` is encodable |

## Operation (pseudocode)

```text
result = FPCompare(Sd, Sm, signal_NaN=True)
FPSCR.{N,Z,C,V} = result
if Sd is NaN or Sm is NaN: FPSCR.IOC = 1
```

The only difference vs `VCMP`: **VCMPE flags Invalid Operation (IOC) for *any* NaN, including quiet NaN.** `VCMP` only flags it for signaling NaNs.

NZCV mapping is identical to VCMP:

| Relation        | N | Z | C | V |
|-----------------|---|---|---|---|
| Equal           | 0 | 1 | 1 | 0 |
| Less than       | 1 | 0 | 0 | 0 |
| Greater than    | 0 | 0 | 1 | 0 |
| Unordered (NaN) | 0 | 0 | 1 | 1 |

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | ✓ | – |

Writes FPSCR.{N,Z,C,V}. APSR untouched — bridge with `VMRS APSR_nzcv, FPSCR`.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 (register)  | 32-bit | `VCMPE.F32 Sd, Sm` |
| T2 (immediate) | 32-bit | `VCMPE.F32 Sd, #0.0` |

32-bit Thumb-2 only.

## Exceptions / faults

- UsageFault (NOCP) if the FPU is disabled.
- Sets `FPSCR.IOC` whenever either operand is NaN. On FPv5-SP no actual exception is taken — `IOC` is sticky and software polls it.

## Example

### Example 1 — ordered compare with NaN trap via IOC

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VCMPE demo: ordered "less than" — treat NaN inputs as a hard error via FPSCR.IOC.
    ldr      r0, =val_a
    ldr      r1, =val_b
    vldr.32  s0, [r0]
    vldr.32  s1, [r0, #4]
    vcmpe.f32 s0, s1            @ ordered compare; IOC set if NaN involved
    vmrs     r2, FPSCR          @ snapshot FPSCR
    tst      r2, #(1 << 0)      @ FPSCR.IOC bit
    bne      nan_path           @ branch if NaN was seen
    vmrs     APSR_nzcv, FPSCR
    blt      a_lt_b
    movs     r3, #0              @ a >= b, no NaN
    b        done
a_lt_b:
    movs     r3, #1
    b        done
nan_path:
    movs     r3, #-1             @ NaN handler
done:
loop:
    b   loop

    .align 2
val_a:
    .float 1.0, 2.0
val_b:
    .float 3.0, 4.0             @ unused, just to keep r1 honest
```

**Walkthrough:**

1. `vldr.32 s0/s1` — pull two floats from a buffer.
2. `vcmpe.f32 s0, s1` — ordered compare. If either was NaN (qNaN or sNaN), `FPSCR.IOC` becomes 1 *and* the NZCV result is the unordered pattern (`C=1, V=1`).
3. `vmrs r2, FPSCR` — read the whole status word. We need `IOC` (bit 0) which `VMRS APSR_nzcv` would discard.
4. `tst r2, #1` then `bne nan_path` — explicit NaN-handling branch. This is exactly *why* VCMPE exists: VCMP would silently say "unordered" for qNaN; VCMPE flags it.
5. If no NaN: `vmrs APSR_nzcv, FPSCR` then `blt` — standard ordered branch.
6. `loop: b loop` — park.

This is the part that bites people: choose `VCMPE` whenever NaN means "input was bad and downstream code shouldn't trust the comparison". Use plain `VCMP` only when you genuinely want unordered = "not less and not greater" silently.

### Example 2 — validate input via IOC + ordered branch

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VCMPE demo 2: only accept S0 if it's an ordered, non-negative number.
    vmov.f32 s0, #2.5
    vmov.f32 s1, #1.0
    vcmpe.f32 s0, s1             @ ordered compare; NaN -> FPSCR.IOC = 1
    vmrs     r0, FPSCR           @ snapshot FPSCR (need IOC, not just NZCV)
    tst      r0, #1              @ FPSCR.IOC == 1 ?
    bne      bad_input           @ NaN seen -> reject
    vmrs     APSR_nzcv, FPSCR    @ no NaN: bridge NZCV for the ordered branch
    blt      lt_path
    movs     r2, #0               @ S0 >= S1
    b        done
lt_path:
    movs     r2, #1               @ S0 < S1
    b        done
bad_input:
    movs     r2, #-1              @ NaN sentinel
done:
loop:
    b   loop
```

**Walkthrough:**

1. `vcmpe.f32 s0, s1` — strict ordered compare. With `2.5` and `1.0` (both finite), no NaN, so `FPSCR.IOC` stays clear and NZCV is "GT".
2. `vmrs r0, FPSCR` — snapshot the *whole* FPSCR. `VMRS APSR_nzcv` would discard IOC; we need it.
3. `tst r0, #1` + `bne bad_input` — explicit NaN gate. This is the `VCMPE`-only payoff: a quiet NaN here would also have routed to `bad_input`, where plain `VCMP` would have silently fallen through to the BLT branch with the unordered NZCV pattern.
4. `vmrs APSR_nzcv, FPSCR` — only reached on clean inputs; bridge for `BLT`.
5. `loop: b loop` — park.

## See also

- [VCMP](VCMP.md) — quiet variant (no signal on QNaN)
- [VMRS](VMRS.md) — read FPSCR (including the sticky IOC bit)
- [VMSR](VMSR.md) — clear sticky exception flags by writing FPSCR

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VCMPE*.
