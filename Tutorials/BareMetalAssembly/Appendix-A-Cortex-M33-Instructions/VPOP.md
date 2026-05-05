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

## See also

- [VPUSH](VPUSH.md) — save counterpart
- [VLDM](VLDM.md) — generalised load-multiple (VPOP = VLDMIA SP!)
- [POP](POP.md) — core-register stack pop

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VPOP*.
