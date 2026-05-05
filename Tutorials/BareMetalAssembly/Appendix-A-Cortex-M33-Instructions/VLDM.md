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

## See also

- [VSTM](VSTM.md) — store-multiple counterpart
- [VPOP](VPOP.md) — VLDMIA SP! specialised for the stack
- [VLDR](VLDR.md) — single-register load
- [LDM](LDM.md) — core-register load-multiple

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VLDM*.
