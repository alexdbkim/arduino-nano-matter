# VMSR — move a core register into an FPU system register (typically FPSCR)

## Class & availability

- **Class:** Floating-point (system / data movement)
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None for FPSCR; some FP system regs are privileged
- **Secure-state required:** No (FPSCR is banked between security states)

## Synopsis

```text
VMSR FPSCR, <Rt>
```

**When you'd actually use this** — VMSR writes FPSCR. Use it to switch the **rounding mode** before a batch of conversions (e.g. RZ — round toward zero — for C-style `(int)f` casts), to enable **flush-to-zero** for performance on denormal-prone signal-processing loops, to **disable** flush-to-zero when you need bit-exact IEEE-754 (FZ off, default rounding), or to **clear** the cumulative exception flags after a probe sequence. Always do read–modify–write via `VMRS` → bitops → `VMSR`; constructing FPSCR from scratch will trash rounding/control bits you didn't mean to touch.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `FPSCR` | destination FP system reg | also legal: `FPEXC` etc. (privileged) |
| `<Rt>` | source core register | `R0`–`R12`, `LR`; not `PC`, not `SP` |

## Operation (pseudocode)

```text
FPSCR = R[t]              @ writes mode, rounding, exception, and flag bits
```

Bits within FPSCR that are RES0 / not implemented on FPv5-SP are ignored.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

VMSR does **not** touch APSR. It *can* overwrite FPSCR.{N,Z,C,V}, but those are FPU flags, not APSR flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `VMSR FPSCR, Rt` |

32-bit Thumb-2 only.

## Exceptions / faults

- UsageFault (NOCP) if the FPU is disabled.
- UsageFault on privileged-only FP system regs from unprivileged code.

## Example

### Example 1 — switch to flush-to-zero + round-toward-zero, then restore

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VMSR demo: enable Flush-to-Zero and set Round-toward-Zero, then restore FPSCR.
    vmrs    r0, FPSCR             @ R0 = current FPSCR
    mov     r1, r0                @ keep a copy in R1 to restore later
    orr     r0, r0, #(1 << 24)    @ FPSCR.FZ = 1 (flush denormals to zero)
    bic     r0, r0, #(3 << 22)    @ clear RMode field
    orr     r0, r0, #(3 << 22)    @ RMode = 0b11 -> Round toward Zero
    vmsr    FPSCR, r0             @ apply new FPU mode
    @ ... do FP work under FZ + RZ here ...
    vmsr    FPSCR, r1             @ restore caller's FPSCR
loop:
    b   loop
```

**Walkthrough:**

1. `vmrs r0, FPSCR` — snapshot current control/status word.
2. `mov r1, r0` — squirrel away the original so we can put it back.
3. `orr r0, r0, #(1<<24)` — set bit 24 (`FZ`, Flush-to-Zero). Denormal results will round to ±0.
4. `bic` then `orr #(3<<22)` — clear the 2-bit `RMode` field, then set it to `0b11` = Round toward Zero. This avoids any stuck bits.
5. `vmsr FPSCR, r0` — installs the new mode word atomically. All subsequent FP ops use it.
6. `vmsr FPSCR, r1` — undo. Important if your callee is supposed to be transparent to the caller's FPU mode.
7. `loop: b loop` — park.

This is the part that bites people: writing FPSCR with arbitrary bits from a register also overwrites the cumulative exception flags (`IXC`, `OFC`, `UFC`, `IOC`, `DZC`) and the cached compare flags. If you only want to change a mode bit, always do *read–modify–write* via VMRS → bitops → VMSR, never construct FPSCR from scratch.

### Example 2 — clear sticky cumulative exception flags after a probe sequence

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VMSR demo 2: clear all sticky exception flags so the next sequence starts clean.
    vmrs     r0, FPSCR            @ R0 = current FPSCR (mode bits + flags)
    bic      r0, r0, #0x9F        @ clear IOC|DZC|OFC|UFC|IXC|IDC (low 5 + IDC bit 7 -> 0x9F)
    vmsr     FPSCR, r0            @ commit cleared flags; mode/rounding untouched
    @ ---- now run the probe ----
    vmov.f32 s0, #1.0
    vmov.f32 s1, #3.0
    vdiv.f32 s2, s0, s1           @ 1/3 will set IXC
    vmrs     r1, FPSCR            @ R1 = post-probe flags
loop:
    b   loop
```

**Walkthrough:**

1. `vmrs r0, FPSCR` — read–modify–write begins. We grab the live FPSCR.
2. `bic r0, r0, #0x9F` — clear bits {0..4, 7} = `IOC, DZC, OFC, UFC, IXC, IDC`. Rounding mode (bits 22–23), FZ (bit 24), and DN (bit 25) are preserved.
3. `vmsr FPSCR, r0` — commit. The next FP op starts with a clean cumulative-flag slate.
4. The probe (`vdiv.f32 s2, s0, s1`) computes `1/3` and dirties `IXC`.
5. `vmrs r1, FPSCR` — `R1` now holds *only* the flags from this probe, not anything inherited.
6. `loop: b loop` — park.

Constructing FPSCR from scratch (e.g. `mov r0, #0; vmsr FPSCR, r0`) would also work to clear flags, but it would silently nuke the rounding mode and FZ/DN configuration. Always RMW.

## See also

- [VMRS](VMRS.md) — read counterpart (and the source of the value you're modifying)
- [MSR](MSR.md) — equivalent for core special registers
- [VCMP](VCMP.md) — operation whose flag output lives in FPSCR

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VMSR*.
