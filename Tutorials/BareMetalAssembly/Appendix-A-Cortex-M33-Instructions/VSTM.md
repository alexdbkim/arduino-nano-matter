# VSTM — store multiple consecutive FPU registers to memory

## Class & availability

- **Class:** Floating-point (data movement)
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
VSTMIA <Rn>{!}, {<Sx>-<Sy>}     @ increment-after
VSTMDB <Rn>!,   {<Sx>-<Sy>}     @ decrement-before; writeback mandatory
VSTM   <Rn>{!}, {<Sx>-<Sy>}     @ alias for VSTMIA
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rn>` | base core register | not `PC` |
| `!` | writeback marker | optional for IA, required for DB |
| `{Sx-Sy}` | register list | non-empty consecutive `S0`–`S31`; up to 16 regs |
| `{Dx-Dy}` | register list (double form) | up to 16 `D` regs |

List must be ascending and contiguous.

## Operation (pseudocode)

```text
addr = (mode == DB) ? Rn - 4*N : Rn
for i in 0..N-1:
    MemA[addr + 4*i, 4] = S[first+i]
if writeback:
    Rn = (mode == IA) ? Rn + 4*N : Rn - 4*N
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 (D-form) | 32-bit | `VSTM{IA,DB} Rn{!}, {Dx-Dy}` |
| T2 (S-form) | 32-bit | `VSTM{IA,DB} Rn{!}, {Sx-Sy}` |

32-bit Thumb-2 only.

## Exceptions / faults

- UsageFault (NOCP) if the FPU is disabled.
- UsageFault on unaligned base.
- BusFault / MemManage on protected or invalid pages.

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
    @ VSTM demo: dump four FPU registers into a memory buffer with writeback.
    ldr      r0, =buf            @ R0 -> base of output buffer
    vmov.f32 s0, #1.0
    vmov.f32 s1, #2.0
    vmov.f32 s2, #3.0
    vmov.f32 s3, #4.0
    vstmia   r0!, {s0-s3}        @ buf[0..3] = S0..S3; R0 += 16
    vmov.f32 s4, #5.0
    vstmia   r0,  {s4}           @ buf[4] = 5.0; R0 unchanged
loop:
    b   loop

    .section .bss
    .align 2
buf:
    .space 20
```

**Walkthrough:**

1. `ldr r0, =buf` — base pointer to writable buffer.
2. Four `vmov.f32` immediates load `1.0..4.0` into `S0..S3`.
3. `vstmia r0!, {s0-s3}` — writes 16 bytes (`S0` at `[R0]`, `S3` at `[R0+12]`), then advances `R0` by 16. After this, `R0` points at `buf[4]`.
4. `vstmia r0, {s4}` — writes a single S register to `[R0]` without modifying `R0`. Yes, a one-element list is legal — VSTM/VSTR overlap here.
5. `loop: b loop` — park.

This is the part that bites people: register order in memory is *always* `S(low)` at the lowest address, regardless of `IA` vs `DB`. The mode only changes how the *base address* is computed, not the order of registers within the burst.

## See also

- [VLDM](VLDM.md) — load-multiple counterpart
- [VPUSH](VPUSH.md) — VSTMDB SP! specialised for the stack
- [VSTR](VSTR.md) — single-register store
- [STM](STM.md) — core-register store-multiple

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VSTM*.
