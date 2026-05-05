# LDM — load multiple consecutive words from memory into a list of registers

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
LDM{IA|FD}{<cond>}  <Rn>{!}, <reglist>     @ increment-after (default)
LDMDB{<cond>}       <Rn>{!}, <reglist>     @ decrement-before
```

`LDMIA` (= `LDMFD`, "full-descending") is the default and what assemblers emit when you write plain `LDM`. `LDMDB` ("empty-ascending") is the matching pop for an `STMDB`/`PUSH`-style growth.

## Operands

| Field      | Type            | Constraints                                                              |
|------------|-----------------|--------------------------------------------------------------------------|
| `<Rn>`     | base register   | R0–R12, R13 (SP), or R14. Address must be word-aligned.                  |
| `!`        | writeback       | If present, `<Rn>` is updated by ±4×count. Required if `<Rn>` is in `<reglist>` only when not loaded. |
| `<reglist>`| register list   | Any subset of R0–R12, R14, R15. PC may appear (interworking branch).     |

`<reglist>` is given in `{r0, r1, r4-r7}` form. Registers are loaded in *increasing* register-number order, regardless of how they're written.

## Operation (pseudocode)

```text
address = R[n];                              @ for IA
@ for DB:  address = R[n] - 4*BitCount(reglist);
for i = 0 to 14
    if reglist<i> == '1' then
        R[i] = MemA[address, 4];
        address = address + 4;
if reglist<15> == '1' then
    LoadWritePC(MemA[address, 4]);           @ interworking branch
if writeback then
    R[n] = R[n] ± 4*BitCount(reglist);
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form                                                              |
|---------|--------|-------------------------------------------------------------------|
| T1      | 16-bit | `LDM <Rn>!, <reglist>` — `<Rn>` and reglist limited to R0–R7; writeback required unless `<Rn>` ∈ reglist. |
| T2 (32) | 32-bit | `LDM.W <Rn>{!}, <reglist>` — full register set including R14/R15. |
| T1 DB   | 32-bit | `LDMDB <Rn>{!}, <reglist>` — only 32-bit form.                    |

## Exceptions / faults

- **UsageFault (UNALIGNED)** on non-word-aligned address — always traps for LDM.
- BusFault / MemManage on bus or MPU error mid-list (instruction is restartable on faults).
- Loading the PC produces an interworking branch; bad target → UsageFault (INVSTATE).

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ LDM demo: bulk-restore registers from a context block.
    ldr     r0, =ctx
    ldm     r0, {r4, r5, r6, r7}        @ r4..r7 from ctx[0..3], r0 unchanged
    ldm     r0!, {r1, r2, r3}           @ load r1..r3 and advance r0 by 12
    @ Decrement-before form (matches STMDB):
    ldr     r8, =ctx_top                @ pointer to one-past-end
    ldmdb   r8!, {r4, r5}               @ r4=ctx_top[-2], r5=ctx_top[-1]; r8 -= 8
loop:
    b       loop

    .data
    .align  2
ctx:
    .word   0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70
ctx_top:
```

**Walkthrough:**

1. `ldm r0, {r4, r5, r6, r7}` — non-writeback: R4 ← `*r0`, R5 ← `*(r0+4)`, ..., R7 ← `*(r0+12)`. R0 itself is unchanged.
2. `ldm r0!, {r1, r2, r3}` — *with* writeback (`!`): after the load, R0 += 12. The bracketed list is reordered by register number; the actual memory order is R1 first (lowest reg), then R2, then R3.
3. `ldmdb r8!, {r4, r5}` — decrement-before: address starts at `r8 - 8`, loads R4 from there and R5 from `r8 - 4`, then R8 -= 8. This is the part that bites people: the assembler letter you write (`IA`/`DB`/`FD`/`EA`) only changes encoding, not the rule that lower-numbered registers always touch lower addresses.

## See also

- [STM](STM.md) — symmetric store-multiple.
- [POP](POP.md) — `LDMIA SP!, …` with SP base.
- [LDR](LDR.md) — single-word load.
- [LDRD](LDRD.md) — load two words; faster than LDM for exactly 2.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.39–C2.4.40 — *LDM/LDMIA/LDMFD* and *LDMDB/LDMEA*.
