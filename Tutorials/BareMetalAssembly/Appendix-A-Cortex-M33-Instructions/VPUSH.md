# VPUSH — push FPU registers onto the stack

## Class & availability

- **Class:** Floating-point (data movement)
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
VPUSH {<Sx>-<Sy>}        @ alias for VSTMDB SP!, {Sx-Sy}
VPUSH {<Dx>-<Dy>}        @ alias for VSTMDB SP!, {Dx-Dy}
```

**When you'd actually use this** — VPUSH is the function-prologue partner to `VPOP`. Use it whenever a function clobbers callee-saved FPU registers (`S16–S31` / `D8–D15` per AAPCS-VFP); the compiler emits it automatically, and you'll write it by hand in asm shims, RTOS task entry stubs, or FPU-using interrupt handlers that need to be transparent to the interrupted code (when lazy FPU stacking isn't doing the job for you).

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `{Sx-Sy}` | register list | consecutive `S0`–`S31`; 1 to 16 registers |
| `{Dx-Dy}` | register list | consecutive `D0`–`D15`; 1 to 16 registers |

`SP` is implicit; you don't (and can't) name a base. The list must be contiguous and ascending.

## Operation (pseudocode)

```text
N    = number_of_regs_in_list
SP   = SP - 4*N
for i in 0..N-1:
    MemA[SP + 4*i, 4] = S[first+i]
```

VPUSH is exactly `VSTMDB SP!, {list}` — same encoding, friendlier mnemonic.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 (D-form) | 32-bit | `VPUSH {Dx-Dy}` |
| T2 (S-form) | 32-bit | `VPUSH {Sx-Sy}` |

32-bit Thumb-2 only.

## Exceptions / faults

- UsageFault (NOCP) if the FPU is disabled.
- UsageFault on unaligned `SP` (must be 4-byte aligned; AAPCS demands 8 at public boundaries).
- BusFault / MemManage on stack overflow.

## Example

### Example 1 — callee-saved save (S16–S17)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VPUSH demo: save callee-saved FPU regs around a "function" that scribbles them.
    vmov.f32 s16, #2.0
    vmov.f32 s17, #4.0
    vpush    {s16-s17}           @ stack: save callee-saved S16, S17
    @ ---- pretend body that clobbers S16/S17 ----
    vmov.f32 s16, #5.0
    vmov.f32 s17, #6.0
    @ ---- end body ----
    vpop     {s16-s17}           @ restore S16, S17 from stack
loop:
    b   loop
```

**Walkthrough:**

1. `vmov.f32 s16, #2.0` / `s17, #4.0` — set up two callee-saved registers (AAPCS treats `S16–S31` as callee-saved).
2. `vpush {s16-s17}` — `SP -= 8`, then writes `S16` at `[SP]` and `S17` at `[SP+4]`. Lowest-numbered register at the lowest address — same as core `PUSH`.
3. The middle two `vmov.f32 #5.0/#6.0` simulate a function body that overwrites the saved values.
4. `vpop {s16-s17}` — reads them back and bumps `SP` by 8.
5. `loop: b loop` — park.

This is the part that bites people: VPUSH/VPOP register lists must be **contiguous**. Saving `{s16, s18}` is illegal — you'd have to save `{s16-s18}` or do two pushes. Also, mixing core PUSH and VPUSH around a call is fine, but be consistent about ordering: typically `PUSH {regs, lr}` first, then `VPUSH {s..}`, and VPOP/POP in reverse.

### Example 2 — D-form push (D8–D11) for double-precision-aliased state

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VPUSH demo 2: D-form push of D8..D11 (== S16..S23 transfer-aliased).
    vpush    {d8-d11}             @ SP -= 32; saves 4 D regs = 8 S regs (S16..S23)
    vmov.f32 s16, #1.0            @ body scribbles the underlying S regs
    vmov.f32 s23, #9.0
    vpop     {d8-d11}             @ undo: list must mirror the VPUSH exactly
loop:
    b   loop
```

**Walkthrough:**

1. `vpush {d8-d11}` — D-form push. On Cortex-M33's FPv5-SP, `D8` aliases the pair `S16:S17`, `D9` aliases `S18:S19`, etc. Even though the FPU can't *compute* on doubles here, the **transfer** instructions still treat `D` regs as 64-bit chunks. SP drops by `4 × 8 = 32` bytes.
2. The body writes via the `S` aliases — both views see the same physical bytes.
3. `vpop {d8-d11}` — symmetric restore. You can mix views (push D, pop S) only if the byte counts and register coverage match exactly; safer to keep the same form.
4. `loop: b loop` — park.

Practical use: the D-form is one byte shorter to write in source and matches what compilers emit for code built with `-mfpu=fpv4-d16` / `-mfpu=fpv5-d16` (double-precision-capable variants). On bare M33+SP you'll most often see the S-form.

## See also

- [VPOP](VPOP.md) — restore counterpart
- [VSTM](VSTM.md) — generalised store-multiple (VPUSH = VSTMDB SP!)
- [PUSH](PUSH.md) — core-register stack push

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VPUSH*.
