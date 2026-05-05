# CBZ — compare and branch forward if register is zero

## Class & availability

- **Class:** Branch
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
CBZ   <Rn>, <label>
```

`CBZ` tests `<Rn>` against zero and, if equal, branches forward to `<label>`. It does **not** read or write any APSR flags — that's why it's so handy: you can use it inside an `IT` block, or right after an instruction whose flags you don't want to disturb. The trade-offs:

- **Forward-only.** The encoded immediate is unsigned; you cannot branch backwards. Trying to assemble `cbz r0, earlier_label` is an error.
- **Tiny range.** 0–126 bytes past the current PC (in 2-byte steps). For longer reaches, use `cmp`+`beq`.
- **Low registers only.** `<Rn>` must be one of `r0`–`r7`.

The classic uses are null-pointer guards on entry to a function and zero-counter checks at the top of a loop.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rn>` | tested register | one of `r0`–`r7` |
| `<label>` | forward target | range +0 to +126 bytes from PC, halfword-aligned |

## Operation (pseudocode)

```text
if Rn == 0 then
    PC = PC + zero_extend(imm)   // forward only
// flags are NEVER updated
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

`CBZ` reads the register value directly; it never touches APSR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `CBZ <Rn>, <label>` — only encoding |

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
    @ CBZ demo: skip work cheaply when the input pointer is null.
    ldr     r0, =buffer         @ r0 = pointer to a buffer
    bl      maybe_clear_first
    @ first byte of buffer is now 0
loop:
    b       loop

    .thumb_func
maybe_clear_first:
    cbz     r0, .Lret           @ if r0 == NULL, return immediately
    movs    r1, #0
    strb    r1, [r0]            @ buffer[0] = 0
.Lret:
    bx      lr

    .align 2
buffer:
    .byte   0xAA, 0xBB, 0xCC, 0xDD
```

**Walkthrough:**

1. `cbz r0, .Lret` — if the pointer is null, jump straight to the return without disturbing any flags. One 16-bit instruction replaces a `cmp`+`beq` pair.
2. `movs r1, #0` — reached only when `r0` is non-null. The compiler-style guard pattern means callers can pass null safely.
3. `strb r1, [r0]` — writes the zero byte.
4. `bx lr` — return path used by both branches; the early-exit and the work-done case converge here.

If you ever needed to branch backwards to a loop top, you'd use `subs`+`bne` instead — `CBZ` cannot reach earlier addresses.

## See also

- [CBNZ](CBNZ.md) — same instruction, opposite sense.
- [B](B.md) — generic conditional branch (reads APSR, longer range, both directions).
- [IT](IT.md) — alternative way to gate a single instruction without branching.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.22 — *CBNZ, CBZ*.
