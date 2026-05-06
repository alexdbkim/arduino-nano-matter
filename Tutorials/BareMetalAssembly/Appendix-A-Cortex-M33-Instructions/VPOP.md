# VPOP — pop FPU registers off the stack

## Class & availability

- **Class:** Floating-point (data movement)
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
VPOP {<Sx>-<Sy>}         @ alias for VLDMIA SP!, {Sx-Sy}
VPOP {<Dx>-<Dy>}         @ alias for VLDMIA SP!, {Dx-Dy}
```

**When you'd actually use this** — `VPOP` is the FPU half of a function epilogue. Per AAPCS-VFP, registers `S16`–`S31` are callee-saved, so any function that uses them must restore the originals before returning; compilers emit a matching `VPUSH` at the top and `VPOP` at the bottom. It also shows up in RTOS context-switch glue (FreeRTOS `xPortPendSVHandler` for non-lazy-stacking ports) and in trampolines that briefly borrow callee-saved FPU registers to hold a hot DSP coefficient across a callback. Without `VPOP`, the same restore would take N separate `VLDR` instructions plus an explicit `ADD SP, SP, #N*4` — bigger and slower than the single multi-register transfer.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `{Sx-Sy}` | register list | consecutive `S0`–`S31`; 1 to 16 registers |
| `{Dx-Dy}` | register list | consecutive `D0`–`D15`; 1 to 16 registers |

`SP` is the implicit base. List must be contiguous, ascending.

## Operation (pseudocode)

```text
N = number_of_regs_in_list
for i in 0..N-1:
    S[first+i] = MemA[SP + 4*i, 4]
SP = SP + 4*N
```

VPOP is exactly `VLDMIA SP!, {list}`.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 (D-form) | 32-bit | `VPOP {Dx-Dy}` |
| T2 (S-form) | 32-bit | `VPOP {Sx-Sy}` |

32-bit Thumb-2 only.

## Exceptions / faults

- UsageFault (NOCP) if the FPU is disabled.
- UsageFault on unaligned `SP`.
- BusFault on bad stack access (e.g. unwound past the stack top).

## Example

### Example 1 — callee-saved restore (S16–S19)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VPOP demo: standard prologue/epilogue protecting S16-S19.
    vpush    {s16-s19}           @ prologue: save callee-saved FP regs
    vmov.f32 s16, #1.0
    vmov.f32 s17, #2.0
    vmov.f32 s18, #3.0
    vmov.f32 s19, #4.0
    vadd.f32 s0, s16, s17        @ use them
    vadd.f32 s1, s18, s19
    vpop     {s16-s19}           @ epilogue: restore them
loop:
    b   loop
```

**Walkthrough:**

1. `vpush {s16-s19}` — pushes 16 bytes; `SP` drops by 16.
2. The four `vmov.f32` writes overwrite `S16..S19` with new values.
3. `vadd.f32` instructions consume them — purely so the example does meaningful work.
4. `vpop {s16-s19}` — reads 16 bytes back: `S16` from `[SP]`, `S19` from `[SP+12]`, then `SP += 16`. Same lowest-reg-at-lowest-addr ordering as VPUSH.
5. `loop: b loop` — park.

This is the part that bites people: VPOP **must** mirror the matching VPUSH list exactly. Popping `{s16-s17}` after pushing `{s16-s19}` does not "do half" — it leaves `SP` mis-aligned with the saved frame and the next return will explode. Always pair VPUSH/VPOP with identical lists.

### Example 2 — epilogue restoring eight callee-saved regs (S16–S23)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VPOP demo 2: function-style frame around a body that scribbles eight callee-saved regs.
    vpush    {s16-s23}            @ prologue: SP -= 32, save S16..S23
    vmov.f32 s16, #1.0            @ body uses callee-saved scratch
    vmov.f32 s17, #2.0
    vmov.f32 s23, #9.0
    vadd.f32 s24, s16, s17        @ S24..S31 are caller-saved, scribble freely
    vpop     {s16-s23}            @ epilogue: restore mirrors prologue exactly
loop:
    b   loop
```

**Walkthrough:**

1. `vpush {s16-s23}` — save the eight callee-saved registers we plan to clobber. SP drops by 32.
2. The body writes to `S16`, `S17`, `S23` (callee-saved, must be restored) and `S24` (caller-saved, free to scribble).
3. `vpop {s16-s23}` — restore. The list is **identical** to the VPUSH list; if you pushed eight, you must pop eight — no exceptions, no partial pops.
4. `loop: b loop` — park.

Caller-saved (`S0–S15`) versus callee-saved (`S16–S31`) is purely an AAPCS convention; the hardware doesn't care. But if your function violates it, every caller in the codebase silently corrupts.

## See also

- [VPUSH](VPUSH.md) — save counterpart
- [VLDM](VLDM.md) — generalised load-multiple (VPOP = VLDMIA SP!)
- [POP](POP.md) — core-register stack pop

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VPOP*.
