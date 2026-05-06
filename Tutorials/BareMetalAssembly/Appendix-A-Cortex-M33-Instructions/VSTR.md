# VSTR — store a single-precision float from an FPU register to memory

## Class & availability

- **Class:** Floating-point (data movement)
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
VSTR.32 <Sd>, [<Rn>{, #±<imm>}]
```

**When you'd actually use this** — VSTR writes one FPU register to memory: store a filter output, push a result back into a `volatile float` field for an ISR to consume, or update one slot of a lookup table. Compilers emit it for every store of a `float` lvalue. For multiple consecutive registers use VSTM — VSTR has no writeback form and handles one register at a time.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>` | source single-precision register | `S0`–`S31` |
| `<Rn>` | base core register | `R0`–`R12`, `SP` (PC not permitted as base for stores) |
| `#<imm>` | immediate offset | multiple of 4, range `-1020 … +1020` |

Suffix `.32` (alias `.F32`); the FPv5-SP unit on M33 has no half/double store.

## Operation (pseudocode)

```text
addr = Rn + (add ? imm : -imm)
MemA[addr, 4] = Sd              @ must be 4-byte aligned
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

VSTR never updates APSR or FPSCR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `VSTR.32 Sd, [Rn, #±imm]` |

32-bit Thumb-2 only. No writeback — use VSTM for pre/post-increment.

## Exceptions / faults

- UsageFault (NOCP) if the FPU is disabled.
- UsageFault on unaligned address.
- BusFault / MemManage on a write-protected or invalid address.

## Example

### Example 1 — compute then write three floats

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VSTR demo: compute a couple of floats and write them to a buffer.
    ldr      r0, =buf            @ R0 -> output buffer
    vmov.f32 s0, #2.5            @ S0 = 2.5
    vmov.f32 s1, #-1.0           @ S1 = -1.0
    vadd.f32 s2, s0, s1          @ S2 = 1.5
    vstr.32  s0, [r0]            @ buf[0] = 2.5
    vstr.32  s1, [r0, #4]        @ buf[1] = -1.0
    vstr.32  s2, [r0, #8]        @ buf[2] = 1.5
loop:
    b   loop

    .section .bss
    .align 2
buf:
    .space 12
```

**Walkthrough:**

1. `ldr r0, =buf` — load the address of the buffer into `R0`.
2. `vmov.f32 s0, #2.5` / `#-1.0` — encode F32 immediates directly.
3. `vadd.f32 s2, s0, s1` — bring an arithmetic op into the demo so the stored values look like a real result, not just constants.
4. `vstr.32 s0, [r0]` — 4 bytes from `S0` land at `buf[0]`. Address must be 4-byte aligned (the `.align 2` directive guarantees this).
5. `vstr.32 s1, [r0, #4]` / `s2, [r0, #8]` — same, with positive immediate offsets. Negative offsets are also legal (`[r0, #-4]`) within ±1020.

This is the part that bites people: VSTR's immediate offset is *scaled by 4* in the encoding, so the assembler will reject odd or unaligned values (`#5`, `#1024`, …) — for those, materialise the address in a core register or use VSTM with writeback.

### Example 2 — write a filter output via a negative immediate offset

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VSTR demo 2: walking pointer with negative offset to back-fill an earlier buffer slot.
    ldr      r0, =buf
    adds     r0, r0, #4            @ R0 -> buf[1]
    vmov.f32 s0, #7.5
    vstr.32  s0, [r0, #-4]         @ buf[0] = 7.5 (write at R0 - 4)
    vmov.f32 s1, #8.5
    vstr.32  s1, [r0]              @ buf[1] = 8.5
    vmov.f32 s2, #9.5
    vstr.32  s2, [r0, #4]          @ buf[2] = 9.5
loop:
    b   loop

    .section .bss
    .align 2
buf:
    .space 12
```

**Walkthrough:**

1. `ldr r0, =buf` then `adds r0, r0, #4` — set `R0` to `buf[1]`. This mirrors how a streaming filter loop typically maintains a pointer that *moves* through a sample buffer.
2. `vstr.32 s0, [r0, #-4]` — store at `R0 - 4 = buf[0]`. Negative immediate offsets are first-class on VSTR (range `±1020` in steps of 4) — useful for back-fill or writing to the previous element of a struct without a second pointer.
3. `vstr.32 s1, [r0]` and `vstr.32 s2, [r0, #4]` — current and next slot. After this sequence `buf` holds `7.5, 8.5, 9.5`.
4. `loop: b loop` — park.

Compared to building the address with `subs`/`adds`+`vstr`, the immediate-offset form saves an instruction *per* store. That matters in tight inner loops.

## See also

- [VLDR](VLDR.md) — the load counterpart
- [VSTM](VSTM.md) — store multiple FPU registers
- [VPUSH](VPUSH.md) — VSTM specialised for the stack
- [STR](STR.md) — core-register store

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VSTR*.
