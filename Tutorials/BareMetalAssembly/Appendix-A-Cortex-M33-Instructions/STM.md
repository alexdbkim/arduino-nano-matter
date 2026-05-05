# STM — store multiple registers to consecutive memory words

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
STM{IA|EA}{<cond>}  <Rn>{!}, <reglist>      @ increment-after (default)
STMDB{<cond>}       <Rn>{!}, <reglist>      @ decrement-before  (== PUSH when Rn=SP!)
```

`STMIA` (= `STMEA`, "empty-ascending") is the default. `STMDB` (= `STMFD`, "full-descending") with `SP!` is exactly what `PUSH` assembles to.

## Operands

| Field      | Type            | Constraints                                                              |
|------------|-----------------|--------------------------------------------------------------------------|
| `<Rn>`     | base register   | R0–R12, SP (R13), R14.                                                   |
| `!`        | writeback       | If present, `<Rn>` is updated by ±4×count.                               |
| `<reglist>`| register list   | Any subset of R0–R12, R14. PC is **not** allowed.                        |

Registers are stored in *increasing* register-number order to *increasing* addresses.

## Operation (pseudocode)

```text
address = R[n];                              @ for IA
@ for DB:  address = R[n] - 4*BitCount(reglist);
for i = 0 to 14
    if reglist<i> == '1' then
        MemA[address, 4] = R[i];
        address = address + 4;
if writeback then
    R[n] = R[n] ± 4*BitCount(reglist);
```

If `<Rn>` is in `<reglist>` with writeback:
- T1 (16-bit IA): the original `Rn` value is stored if it's the *first* in the list; otherwise UNKNOWN.
- T2 (32-bit): UNPREDICTABLE if `<Rn>` is in `<reglist>` and writeback is selected.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form                                                              |
|---------|--------|-------------------------------------------------------------------|
| T1      | 16-bit | `STM <Rn>!, <reglist>` — `<Rn>` and reglist limited to R0–R7; writeback mandatory. |
| T2 (32) | 32-bit | `STM.W <Rn>{!}, <reglist>` — full register set.                   |
| T1 DB   | 32-bit | `STMDB <Rn>{!}, <reglist>` — only 32-bit form.                    |

## Exceptions / faults

- **UsageFault (UNALIGNED)** if address not word-aligned — always traps.
- BusFault / MemManage / SecureFault as usual.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ STM demo: save a context block, and emulate PUSH via STMDB on SP.
    ldr     r0, =ctx
    movs    r4, #0x44
    movs    r5, #0x55
    movs    r6, #0x66
    movs    r7, #0x77
    stm     r0!, {r4-r7}            @ ctx[0..3] = r4..r7; r0 += 16
    @ STMDB SP! is exactly PUSH {...}:
    stmdb   sp!, {r4, r5, lr}       @ same encoding as PUSH {r4, r5, lr}
    ldmia   sp!, {r4, r5, lr}       @ matching POP
loop:
    b       loop

    .data
    .align  2
ctx:
    .space  32
```

**Walkthrough:**

1. `stm r0!, {r4-r7}` — writes R4 at `*r0`, R5 at `*(r0+4)`, …, R7 at `*(r0+12)`, then advances R0 by 16. Note the order: lowest register goes to the lowest address.
2. `stmdb sp!, {r4, r5, lr}` — decrement-before with SP writeback: SP first drops by 12, then registers are written. This is *literally* what `PUSH {r4, r5, lr}` assembles to.
3. `ldmia sp!, {r4, r5, lr}` — symmetric POP. This is the part that bites people: the AAPCS-mandated stack on Cortex-M is full-descending — i.e. **STMDB / LDMIA on SP** — get those backwards and you'll trash the stack frame on the way back.

## See also

- [LDM](LDM.md) — symmetric load-multiple.
- [PUSH](PUSH.md) — alias for `STMDB SP!`.
- [STR](STR.md) — single-word store.
- [STRD](STRD.md) — paired-word store.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.165–C2.4.166 — *STM/STMIA/STMEA* and *STMDB/STMFD*.
