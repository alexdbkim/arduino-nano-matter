# DSB — data synchronisation barrier; wait for all prior memory accesses to complete

## Class & availability

- **Class:** System (barrier)
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
DSB {<option>}         @ option defaults to SY
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<option>` | barrier domain | `SY` (full system, default), `ST` (stores only), `ISH`/`ISHST`, `NSH`/`NSHST`, `OSH`/`OSHST`. On a single-master M33 the inner/outer/non-shareable forms behave like `SY`. |

## Operation (pseudocode)

```text
// Stall the core until every explicit memory access issued before
// the DSB has completed (writes drained, reads delivered, side
// effects to the bus visible). Subsequent instructions do not
// start executing until then. Implies the ordering of DMB.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1111 0011 1011 1111 1000 1111 0100 ssss` (`F3BF 8F4s`, `s` = option) |

No 16-bit form.

## Exceptions / faults

- (none).

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Trigger PendSV from thread code: write the SCB then sleep.
    ldr     r0, =0xE000ED04         @ ICSR
    ldr     r1, =0x10000000         @ PENDSVSET
    str     r1, [r0]                @ request PendSV
    dsb                             @ make sure the write reaches the SCB
    isb                             @ and that we refetch with PendSV pending
    wfi                             @ now safe to sleep
loop:
    b   loop
```

**Walkthrough:**

1. `str r1, [r0]` — pokes `PENDSVSET` in the System Control Block.
2. `dsb` — without it, the store can still be sitting in the write buffer when we try to sleep, so the IRQ never becomes pending and `WFI` waits forever (or worse: races).
3. `isb` — guarantees the instructions after the barrier observe the new SCB state.
4. `wfi` — sleep until PendSV (or any other IRQ) fires.

Use `DSB` whenever a memory write is the *trigger* for something architectural: enabling the MPU, kicking a DMA, posting an NVIC pend bit, or arming a sleep. It's also required after `SCB->VTOR` writes, before invoking the new vector table.

## See also

- [DMB](DMB.md) — orders accesses without stalling completion
- [ISB](ISB.md) — flushes the pipeline; usually pair `DSB; ISB`
- [WFI](WFI.md), [WFE](WFE.md) — common sites for a preceding DSB

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.50 — *DSB*.
