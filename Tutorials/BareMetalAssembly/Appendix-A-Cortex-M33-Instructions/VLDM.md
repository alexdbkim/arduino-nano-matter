# VLDM — load multiple consecutive FPU registers from memory

## Class & availability

- **Class:** Floating-point (data movement)
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
VLDMIA <Rn>{!}, {<Sx>-<Sy>}     @ increment-after; ! = writeback
VLDMDB <Rn>!,   {<Sx>-<Sy>}     @ decrement-before; writeback mandatory
VLDM   <Rn>{!}, {<Sx>-<Sy>}     @ alias for VLDMIA
```

**When you'd actually use this** — VLDM moves *several* consecutive FPU registers in or out in a single instruction. Three real-world settings: (1) bulk register save/restore in an RTOS context switch when you aren't relying on lazy FPU stacking; (2) DMA-style transfer of an N-element vector or filter-tap block from RAM into the register file before a DSP kernel; (3) fast restore of a saved math frame. Compared to a sequence of `VLDR`s, VLDM is one instruction, encodes the length compactly, and the core can pipeline the burst.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rn>` | base core register | not `PC` |
| `!` | writeback marker | optional for IA, required for DB |
| `{Sx-Sy}` | register list | non-empty consecutive `S0`–`S31`; up to 16 regs per instruction |
| `{Dx-Dy}` | register list (double form) | up to 16 `D` regs (= 32 `S` regs in pairs) |

The list is always *consecutive* and ascending. Holes (`{S0, S2}`) are not allowed.

## Operation (pseudocode)

```text
addr = (mode == DB) ? Rn - 4*N : Rn
for i in 0..N-1:
    S[first+i] = MemA[addr + 4*i, 4]
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
| T1 (D-form) | 32-bit | `VLDM{IA,DB} Rn{!}, {Dx-Dy}` |
| T2 (S-form) | 32-bit | `VLDM{IA,DB} Rn{!}, {Sx-Sy}` |

32-bit Thumb-2 only. The unit transfers exactly *N* words (single) or *2N* words (double-form).

## Exceptions / faults

- UsageFault (NOCP) if the FPU is disabled.
- UsageFault on unaligned base.
- BusFault on inaccessible memory.
- The transfer is **not** restartable; an exception mid-transfer leaves architectural state defined by the FPU's lazy-context rules.

## Example

### Example 1 — load a 6-element vector with and without writeback

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VLDM demo: pull a 4-element vector from a table into S0..S3.
    ldr      r0, =vec            @ R0 -> vec[0]
    vldmia   r0!, {s0-s3}        @ S0..S3 = vec[0..3]; R0 advances by 16
    vldmia   r0,  {s4-s5}        @ S4..S5 = vec[4..5]; R0 unchanged
loop:
    b   loop

    .align 2
vec:
    .float 1.0, 2.0, 3.0, 4.0, 5.0, 6.0
```

**Walkthrough:**

1. `ldr r0, =vec` — get the base address.
2. `vldmia r0!, {s0-s3}` — load four words starting at `[R0]` into `S0..S3` (in order: `S0` low addr, `S3` high addr). The `!` makes `R0 += 16` afterwards, so it now points at `vec[4]`.
3. `vldmia r0, {s4-s5}` — load two more, but **without** `!`, so `R0` is unchanged.
4. `loop: b loop` — park.

This is the part that bites people: the register list must be **consecutive** (`{s0-s3}`, never `{s0, s2}`) and **ascending**, and the count is encoded in the instruction — it's not a runtime length. `VLDMDB` (decrement-before) requires `!` because non-writeback DB makes no architectural sense.

### Example 2 — load four taps and four samples for a dot product

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VLDM demo 2: 4-tap FIR step — load taps and samples in two bursts, then FMAC.
    ldr      r0, =taps
    ldr      r1, =samples
    vldmia   r0, {s0-s3}          @ S0..S3 = taps[0..3]
    vldmia   r1, {s4-s7}          @ S4..S7 = samples[0..3]
    vmul.f32 s8, s0, s4           @ S8  = t0*x0
    vfma.f32 s8, s1, s5           @ S8 += t1*x1
    vfma.f32 s8, s2, s6           @ S8 += t2*x2
    vfma.f32 s8, s3, s7           @ S8 += t3*x3 (one FIR output sample)
loop:
    b   loop

    .align 2
taps:    .float 0.25, 0.25, 0.25, 0.25
samples: .float 1.0, 2.0, 3.0, 4.0
```

**Walkthrough:**

1. Two `vldmia` bursts pull eight floats into the register file in two instructions; the DSP equivalent of `for (i=0;i<4;i++) load(...)` collapsed to two memory transactions.
2. `vmul.f32 s8, s0, s4` seeds the accumulator with the first product.
3. Three `vfma.f32` instructions — fused multiply-add — fold in the remaining three taps without any rounding between steps. Total: 4 multiplies, 3 adds, one rounded result.
4. `loop: b loop` — park.

This pattern is why VLDM exists: filling the register file for a kernel that runs entirely out of registers, with no per-element memory traffic during the math.

## See also

- [VSTM](VSTM.md) — store-multiple counterpart
- [VPOP](VPOP.md) — VLDMIA SP! specialised for the stack
- [VLDR](VLDR.md) — single-register load
- [LDM](LDM.md) — core-register load-multiple

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VLDM*.
