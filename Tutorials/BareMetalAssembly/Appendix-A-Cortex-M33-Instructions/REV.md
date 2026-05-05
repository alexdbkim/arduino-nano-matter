# REV — reverse byte order of a 32-bit word (endianness swap)

## Class & availability

- **Class:** Bit manipulation
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
REV{<cond>} <Rd>, <Rm>
```

Writes to `<Rd>` the bytes of `<Rm>` in reverse order: byte 0 ↔ byte 3, byte 1 ↔ byte 2. Used to convert between little-endian (the Cortex-M33 default on this board) and big-endian (network byte order, many wire protocols).

## Operands

| Field  | Type        | Constraints                                       |
|--------|-------------|---------------------------------------------------|
| `<Rd>` | destination | R0–R7 (T1) or R0–R12, LR (T2). Not SP, not PC.    |
| `<Rm>` | source      | Same constraint as `<Rd>` for the chosen encoding. |

## Operation (pseudocode)

```text
if ConditionPassed() then
    Rd<31:24> = Rm<7:0>;
    Rd<23:16> = Rm<15:8>;
    Rd<15:8>  = Rm<23:16>;
    Rd<7:0>   = Rm<31:24>;
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width  | Form                                   | Notes                              |
|---------|--------|----------------------------------------|------------------------------------|
| T1      | 16-bit | `1011 1010 00 Rm Rd`                   | Low registers (R0–R7) only.        |
| T2      | 32-bit | `11111010 1001 Rm 1111 Rd 1000 Rm`     | Full register range.               |

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
    @ REV demo: convert a big-endian 32-bit field from a network packet
    @ into the CPU's native little-endian representation.
    ldr     r0, =0x12345678      @ raw bytes as read from packet (BE on wire)
    rev     r1, r0               @ r1 = 0x78563412  (now native LE)
    @ Equivalent C:  htonl()/ntohl() in one cycle.

    @ Also useful when reading a LE word but you need BE for output.
    ldr     r2, =0xCAFEBABE
    rev     r3, r2               @ r3 = 0xBEBAFECA
loop:
    b   loop
```

**Walkthrough:**

1. `ldr r0, =0x12345678` — pretend this came from `LDR` of a 32-bit big-endian field. Bytes in memory order: 12 34 56 78.
2. `rev r1, r0` — flips byte order so the high byte and low byte swap, and the two middle bytes swap. Result is `0x78563412`, i.e. the CPU now sees the value the sender meant.
3. `rev r3, r2` — same operation in the other direction; `REV` is its own inverse.

This is the part that bites people: `REV` swaps **bytes**, not bits. If you wanted a bit-mirror, use [`RBIT`](RBIT.md). If you only need the low halfword, use [`REV16`](REV16.md). If you have a signed 16-bit big-endian value, [`REVSH`](REVSH.md) does the swap and sign-extends in one step.

## See also

- [REV16](REV16.md) — byte-swap each halfword independently.
- [REVSH](REVSH.md) — byte-swap the low halfword and sign-extend to 32 bits.
- [RBIT](RBIT.md) — bit-level reverse (not byte-level).

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.123 — *REV*.
