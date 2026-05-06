# VMOV — move between FPU registers, between FPU and core registers, or load an immediate into an FPU register

## Class & availability

- **Class:** Floating-point (data movement)
- **Architecture:** ARMv8-M Mainline + FP
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
VMOV.F32 <Sd>, #<imm>            @ form 1: 8-bit encoded F32 immediate
VMOV     <Sd>, <Sm>              @ form 2: register copy (single)
VMOV     <Sn>, <Rt>              @ form 3a: core -> FPU single
VMOV     <Rt>, <Sn>              @ form 3b: FPU single -> core
VMOV     <Sm>, <Sm1>, <Rt>, <Rt2>@ form 4a: two cores -> two consecutive S regs
VMOV     <Rt>, <Rt2>, <Sm>, <Sm1>@ form 4b: two S regs -> two cores
VMOV     <Dm>, <Rt>, <Rt2>       @ form 5a: two cores -> one D reg (Rt=low half)
VMOV     <Rt>, <Rt2>, <Dm>       @ form 5b: one D reg -> two cores
```

**When you'd actually use this** — VMOV is the multi-tool of FPU data movement: copy an FPU register to another, drop a small immediate constant straight into a register (`vmov.f32 s0, #1.0`), or shuttle a 32/64-bit value between core and FPU without going through memory. The core↔FPU forms are essential when you need to print a float (extract the bit pattern into a GPR for the printf path) or feed an integer-encoded value into a float register without an int→float convert. Note: VMOV moves *bits*, never converts — for that you want VCVT.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Sd>`, `<Sm>`, `<Sn>` | single-precision FPU register | `S0`–`S31` |
| `<Dm>` | double-precision FPU register | `D0`–`D15` (= pair `S(2n):S(2n+1)`) |
| `<Rt>`, `<Rt2>` | core register | not `PC`; `Rt2 ≠ Rt` for paired forms |
| `#<imm>` | F32 immediate | a value encodable as 8-bit VFP immediate (sign + 3-bit exponent + 4-bit mantissa) |
| `<Sm1>` | second single | must be `S(m+1)` |

## Operation (pseudocode)

```text
form1:  Sd = VFPExpandImm(imm8)
form2:  Sd = Sm
form3a: Sn = R[t]
form3b: R[t] = Sn
form4a: Sm = R[t]; S(m+1) = R[t2]
form4b: R[t] = Sm; R[t2] = S(m+1)
form5a: D[m]<31:0>  = R[t];  D[m]<63:32> = R[t2]
form5b: R[t]  = D[m]<31:0>;  R[t2]       = D[m]<63:32>
```

> Cortex-M33 on EFR32MG24 has no double-precision arithmetic, but `D0`–`D15` exist as transfer aliases over the `S0`–`S31` bank. Form 5 is therefore legal for **moving a 64-bit value** between two core registers and the FPU bank, even though you can't *compute* on `Dm`.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

VMOV never updates APSR or FPSCR condition flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T2 (immediate) | 32-bit | `VMOV.F32 Sd, #imm` |
| T2 (register)  | 32-bit | `VMOV Sd, Sm` |
| T1 (core↔single) | 32-bit | `VMOV Sn, Rt` / `VMOV Rt, Sn` |
| T1 (2-core↔2-single) | 32-bit | `VMOV Sm, Sm1, Rt, Rt2` |
| T1 (2-core↔double)   | 32-bit | `VMOV Dm, Rt, Rt2` |

All VMOV forms are 32-bit Thumb-2 only — there is no 16-bit encoding.

## Exceptions / faults

- UsageFault (NOCP) if the FPU is disabled (`CPACR.CP10/CP11 ≠ 0b11`).
- No memory access, so no alignment or bus faults.

## Example

### Example 1 — all five forms in one walk

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VMOV demo: load 1.0, copy, shuttle to/from core, then bundle 64 bits.
    vmov.f32  s0, #1.0          @ form 1: S0 = 1.0
    vmov      s1, s0            @ form 2: S1 = S0
    ldr       r0, =0x40400000   @ bit pattern for 3.0f
    vmov      s2, r0            @ form 3a: S2 = 3.0f
    vmov      r1, s2            @ form 3b: R1 = bit pattern of S2
    vmov      s4, s5, r0, r1    @ form 4a: pack two cores into S4:S5
    vmov      d3, r0, r1        @ form 5a: pack two cores into D3 (= S6:S7)
    vmov      r2, r3, d3        @ form 5b: unpack D3 back into R2:R3
loop:
    b   loop
```

**Walkthrough:**

1. `vmov.f32 s0, #1.0` — encodes `1.0f` directly in the instruction; no literal pool needed.
2. `vmov s1, s0` — pure FPU register copy, doesn't touch core registers or memory.
3. `vmov s2, r0` — drops the raw 32-bit pattern in `R0` into `S2` *as bits* (no int→float conversion; for that use `VCVT`). The bit pattern `0x40400000` is `3.0f`.
4. `vmov r1, s2` — reverse direction; `R1` now holds `0x40400000`.
5. `vmov s4, s5, r0, r1` — paired transfer: `S4 ← R0`, `S5 ← R1` in one instruction.
6. `vmov d3, r0, r1` — same 64 bits, but addressed as the double-word alias `D3`. `R0` is the *low* word. This is the part that bites people: `Rt` is low, `Rt2` is high, regardless of endianness of memory.
7. `vmov r2, r3, d3` — reads it back out.

### Example 2 — extract a float result into R0 for the AAPCS soft-float return path

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .fpu    fpv5-sp-d16
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)
    @ VMOV demo 2: compute a float result, then ship its bit pattern via R0 (soft-float ABI).
    vmov.f32 s0, #2.0
    vmov.f32 s1, #3.0
    vadd.f32 s0, s0, s1           @ S0 = 5.0
    vmov     r0, s0               @ R0 = bit pattern of 5.0 (0x40A00000)
    vmov.f32 s2, #1.0
    vmov     s3, r0               @ S3 <- raw bits back into FPU (no int->float convert)
loop:
    b   loop
```

**Walkthrough:**

1. `vadd.f32 s0, s0, s1` — produce a real float result (`5.0f`).
2. `vmov r0, s0` — copy the **32 bits** of `S0` into `R0`. `R0` now contains the IEEE-754 encoding `0x40A00000`. This is exactly how the soft-float ABI (`-mfloat-abi=soft`) returns a `float`: in `R0`. With `-mfloat-abi=hard` the float would already be in `S0` and no VMOV is needed.
3. `vmov s3, r0` — round trip back. Critically this is **not** an int→float conversion; the bits are preserved verbatim. If you wanted to *convert* (e.g. `int 5` → `5.0f`), you'd need `VCVT.F32.S32`.
4. `loop: b loop` — park.

## See also

- [VLDR](VLDR.md) — load a single from memory instead of a core register
- [VSTR](VSTR.md) — store a single to memory
- [VMRS](VMRS.md) / [VMSR](VMSR.md) — move between FPSCR and a core register
- [MOV](MOV.md) — core-to-core register move

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4 — *VMOV (immediate / register / between core and FP / between two cores and FP)*.
