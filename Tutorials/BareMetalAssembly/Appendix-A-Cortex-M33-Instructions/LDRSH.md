# LDRSH — load a signed half-word from memory, sign-extended to 32 bits

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
LDRSH{<cond>}  <Rt>, [<Rn>{, #<imm>}]
LDRSH{<cond>}  <Rt>, [<Rn>, <Rm>{, LSL #<n>}]
LDRSH{<cond>}  <Rt>, [<Rn>, #<imm>]!
LDRSH{<cond>}  <Rt>, [<Rn>], #<imm>
LDRSH{<cond>}  <Rt>, <label>
```

Reads 16 bits and **sign-extends** bit 15 to bit 31. The natural way to load `int16_t`.

**When you'd actually use this.** `LDRSH` is for `int16_t` data: signed PCM audio samples, motor-control encoder counts, accelerometer/gyro readings (most IMUs ship 16-bit two's-complement words), or DSP coefficient tables. The sign-extension to 32 bits is what makes a subsequent multiply, add, or compare give the right arithmetic answer. The matching DSP MAC patterns (`smlabb`, `smlad`, `mla` with signed operands) consume signed half-words and they expect inputs that have been brought into registers via `LDRSH`. The alternative — `LDRH` + `SXTH` — burns an extra instruction every time you touch the buffer; in the inner loop of a filter that adds up fast.

## Operands

| Field   | Type                 | Constraints                              |
|---------|----------------------|------------------------------------------|
| `<Rt>`  | destination register | R0–R14.                                  |
| `<Rn>`  | base register        | R0–R15.                                  |
| `<Rm>`  | index register       | R0–R12.                                  |
| `<imm>` | offset               | T1/T2: imm12 / imm8 with sign.           |

Address must be half-word aligned unless `CCR.UNALIGN_TRP = 0`.

## Operation (pseudocode)

```text
offset_addr = R[n] + offset;
address     = (index) ? offset_addr : R[n];
R[t]        = SignExtend(MemU[address, 2], 32);
if wback then R[n] = offset_addr;
@ Flags unchanged.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form                                                       |
|---------|--------|------------------------------------------------------------|
| T1      | 16-bit | `LDRSH <Rt>, [<Rn>, <Rm>]` — register offset, low regs only.|
| T1 (32) | 32-bit | `LDRSH.W <Rt>, [<Rn>, #<imm12>]`.                          |
| T2 (32) | 32-bit | `LDRSH.W <Rt>, [<Rn>, #±<imm8>]{!}` / post-indexed.        |
| T2 (32) | 32-bit | `LDRSH.W <Rt>, [<Rn>, <Rm>{, LSL #0–3}]`.                  |
| T1 lit  | 32-bit | `LDRSH.W <Rt>, <label>`.                                   |

No 16-bit immediate-offset form — immediate `LDRSH` is always 32-bit.

## Exceptions / faults

- **UsageFault (UNALIGNED)** if `CCR.UNALIGN_TRP = 1` and address is odd.
- BusFault / MemManage on bus or MPU error.

## Example

### Example 1 — reading int16 PCM audio samples

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ LDRSH demo: reading int16_t audio samples (signed PCM).
    ldr     r0, =samples
    ldrsh   r1, [r0]                @ r1 = (int32_t)((int16_t)*r0)
    ldrsh   r2, [r0, #2]            @ next sample
    movs    r3, #2                  @ index of 3rd element
    ldrsh   r4, [r0, r3, lsl #1]    @ scaled: r0 + r3*2
    ldrsh   r5, [r0], #2            @ post-index *p++
loop:
    b       loop

    .align  2
samples:
    .hword  -1, 32767, -32768, 0
```

**Walkthrough:**

1. `ldrsh r1, [r0]` — value is -1 (0xFFFF). After sign-extension R1 = 0xFFFFFFFF.
2. `ldrsh r2, [r0, #2]` — 32767 (0x7FFF). Bit 15 = 0, R2 = 0x00007FFF.
3. `ldrsh r4, [r0, r3, lsl #1]` — -32768 (0x8000). Bit 15 = 1, R4 = 0xFFFF8000 (-32768). A plain `LDRH` would produce 0x00008000 (+32768) — that's the trap.
4. `ldrsh r5, [r0], #2` — streaming int16 read with auto-increment by 2.

### Example 2 — 4-tap FIR multiply-accumulate over int16 samples

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ LDRSH demo 2: 4-tap FIR sum-of-products on int16 samples and coeffs.
    ldr     r0, =samples
    ldr     r1, =coeffs
    movs    r2, #4                  @ tap count
    movs    r3, #0                  @ accumulator
fir_loop:
    ldrsh   r4, [r0], #2            @ next sample (sign-extended)
    ldrsh   r5, [r1], #2            @ next coefficient
    mla     r3, r4, r5, r3          @ acc += sample * coeff
    subs    r2, r2, #1
    bne     fir_loop
loop:
    b       loop

    .align  2
samples:
    .hword  -1, 32767, -32768, 100
coeffs:
    .hword   1,    -1,      2,   3
```

**Walkthrough:**

1. `ldrsh r4, [r0], #2` and `ldrsh r5, [r1], #2` — post-indexed signed half-word loads, advancing each pointer by 2 (one `int16_t`). Sign-extension is essential: a sample of −32768 must enter the multiplier as 0xFFFF8000, not 0x00008000.
2. `mla r3, r4, r5, r3` — multiply-and-accumulate: `r3 = r4*r5 + r3`. With proper sign-extension, the 32-bit product is correctly signed and the accumulator stays consistent.
3. `subs r2, r2, #1` / `bne fir_loop` — standard tap-count loop tail.

## See also

- [LDRH](LDRH.md) — zero-extending half-word load (for `uint16_t`).
- [LDRSB](LDRSB.md) — sign-extending byte load.
- [LDR](LDR.md) — full word.
- [STRH](STRH.md) — half-word store.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.56–C2.4.57 — *LDRSH (immediate/literal/register)*.
