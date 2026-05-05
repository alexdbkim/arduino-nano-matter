# REVSH — byte-swap the low halfword and sign-extend to 32 bits

## Class & availability

- **Class:** Bit manipulation
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
REVSH{<cond>} <Rd>, <Rm>
```

Swaps bytes within `<Rm>[15:0]`, then sign-extends the resulting 16-bit value to 32 bits. Designed for reading a signed big-endian 16-bit field (e.g. a temperature sample from an I²C sensor) and producing the correctly signed native int in one instruction.

## Operands

| Field  | Type        | Constraints                                       |
|--------|-------------|---------------------------------------------------|
| `<Rd>` | destination | R0–R7 (T1) or R0–R12, LR (T2). Not SP, not PC.    |
| `<Rm>` | source      | Same constraint as `<Rd>` for the chosen encoding. The upper 16 bits of `<Rm>` are ignored. |

## Operation (pseudocode)

```text
if ConditionPassed() then
    Rd<7:0>   = Rm<15:8>;
    Rd<15:8>  = Rm<7:0>;
    Rd<31:16> = Replicate(Rm<7>, 16);   // sign-extend from new bit 15
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width  | Form                                   | Notes                              |
|---------|--------|----------------------------------------|------------------------------------|
| T1      | 16-bit | `1011 1010 11 Rm Rd`                   | Low registers (R0–R7) only.        |
| T2      | 32-bit | `11111010 1001 Rm 1111 Rd 1011 Rm`     | Full register range.               |

## Exceptions / faults

- (none)

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ REVSH demo: a sensor returns a signed 16-bit value in big-endian byte order.
    @ Raw word (as if loaded from a halfword register): 0x0000FF80
    @ Bytes on the wire:  0xFF 0x80  -> meant as 0x80FF (signed BE)
    @ After byte-swap:    0x80FF in low halfword
    @ As a signed 16-bit value: -32513
    ldr     r0, =0x0000FF80
    revsh   r1, r0               @ r1 = 0xFFFF80FF  (signed -32513 in 32-bit form)

    @ Positive case: bytes 0x00 0x7F -> 0x7F00 -> +32512
    ldr     r2, =0x0000007F
    revsh   r3, r2               @ r3 = 0x00007F00 (+32512), no sign extension needed
loop:
    b   loop
```

**Walkthrough:**

1. `ldr r0, =0x0000FF80` — the low halfword `0xFF80` is the raw big-endian sensor reading. The high halfword is ignored by `REVSH`.
2. `revsh r1, r0` — swaps the two bytes (`0xFF80 → 0x80FF`), then notices the new bit 15 is `1`, so it fills bits 31..16 with ones. Result: `0xFFFF80FF`, the correct 32-bit signed representation of the sensor's −32513.
3. `revsh r3, r2` — for a non-negative value, the new bit 15 is `0`, so the upper bits stay zero. No surprise.

Use `REVSH` whenever you would otherwise write `REV16` followed by `SXTH`. It does both jobs in one cycle.

## See also

- [REV16](REV16.md) — same byte swap, but no sign extension and works on both halfwords.
- [SXTH](SXTH.md) — sign-extend a 16-bit value without swapping bytes.
- [REV](REV.md) — full 32-bit byte reversal.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.125 — *REVSH*.
