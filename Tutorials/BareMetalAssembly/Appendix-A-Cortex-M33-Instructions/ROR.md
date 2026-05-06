# ROR — rotate right

## Class & availability

- **Class:** Shift/Rotate
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
ROR{S}{<cond>} {<Rd>,} <Rm>, #<imm>           @ immediate form, imm = 1..31
ROR{S}{<cond>} {<Rd>,} <Rn>, <Rs>             @ register form
```

Rotate the 32-bit value right by N bits — bits that fall off the right reappear on the left. There is **no `ROL`**: rotate-left by N is `ROR` by `32 − N`.

**When you'd actually use this** is **rotating bits without losing them** — used in CRC inner loops, hash mixing functions like SipHash, and any bit-stream code that re-uses a register as two halves. Because bits wrap around instead of falling off, `ROR` is reversible: rotating by N and then by `32 − N` recovers the original. When you actually want a logical shift (and *don't* care about the bits that fall off), prefer `LSL`/`LSR` — they're conceptually cheaper and don't lie about where the bits went.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | R0–R12, LR; R0–R7 (T1) |
| `<Rm>` / `<Rn>` | source register | R0–R12, LR; R0–R7 (T1) |
| `<Rs>` | rotate-amount register | only low 8 bits used (modulo 32 happens implicitly) |
| `#<imm>` | rotate amount | 1..31 (a count of 0 with the immediate encoding is `RRX`) |

## Operation (pseudocode)

```text
if ConditionPassed() then
    n = (immediate form) ? imm : UInt(R[s]<4:0>)        @ register form rotates mod 32
    (result, carry) = ROR_C(R[m], n)
    R[d] = result
    if S == '1' then
        APSR.N = result<31>
        APSR.Z = IsZeroBit(result)
        APSR.C = carry                                  @ = result<31> after rotate
        @ APSR.V unchanged
```

For the register form, `Rs<7:0> == 0` ⇒ no rotate; C unchanged.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓ | ✓ | ✓ | – | – |

`RORS` only. C ends up equal to the new bit 31 (the bit that just rotated into the top).

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `RORS <Rdn>, <Rm>` — register, low registers |
| T2 | 32-bit | `ROR{S}.W <Rd>, <Rm>, #<imm>` — immediate (1..31) |
| T2 | 32-bit | `ROR{S}.W <Rd>, <Rn>, <Rs>` — register |

The 16-bit immediate `ROR` form does **not** exist — only 32-bit. The 16-bit register form does exist.

## Exceptions / faults

- (none).

## Example

### Example 1 — byte/halfword rotates

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ ROR demo: byte-swap nibbles, plus a register-form rotate.
    ldr     r0, =0xDEADBEEF
    ror     r1, r0, #16            @ r1 = 0xBEEFDEAD (swap halves)
    ror     r2, r0, #8             @ r2 = 0xEFDEADBE (rotate by one byte)
    mov     r3, #4
    rors    r4, r0, r3             @ register form: r4 = 0xFDEADBEE, flags set
loop:
    b   loop
```

**Walkthrough:**

1. `ror r1, r0, #16` — rotating by 16 swaps the two halves. Frequently used for endian fiddling alongside `REV`.
2. `ror r2, r0, #8` — moves the bottom byte to the top. Combined with masks this builds custom permutations.
3. `rors r4, r0, r3` — register-form rotate by `r3 = 4`. With `S`, you can test the new MSB via N or the rotated-in bit via C.

### Example 2 — feed a CRC byte-by-byte

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Rotate a 32-bit word right by 8 to expose the next byte at the bottom —
    @ a common pattern in CRC and hash inner loops.
    ldr     r0, =0xDEADBEEF
    ror     r0, r0, #8             @ r0 = 0xEFDEADBE  (next byte: 0xBE)
    ror     r0, r0, #8             @ r0 = 0xBEEFDEAD  (next byte: 0xAD)
loop:
    b   loop
```

**Walkthrough:** Each `ROR #8` brings the previous low byte to the top and exposes the next byte at the bottom — perfect for loops that consume one byte per iteration without ever reloading from memory. Using `LSR #8` instead would *lose* the byte that fell off the right end, breaking the rotation.

## See also

- [RRX](RRX.md) — rotate right *through* the carry flag (33-bit rotate).
- [LSR](LSR.md), [ASR](ASR.md), [LSL](LSL.md) — the shifters.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.140 — *ROR (immediate)* and §C2.4.141 — *ROR (register)*.
