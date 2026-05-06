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

**When you'd actually use this** — `DSB` is `DMB` with teeth: it *stalls execution* until every preceding memory access has actually completed (writes drained to the bus, reads delivered). Required after writing system control registers — `MPU_CTRL`, `SCB->VTOR`, `NVIC->ISER`, `SCB->AIRCR` — to guarantee the reconfiguration is in effect before subsequent code runs. Required before `WFI`/`WFE` when the wake source was just armed via MMIO, otherwise the arming write may still be in the write buffer when the core sleeps and the wake never arrives. Versus `DMB` it costs more cycles but is the right choice when you need *completion*, not just *ordering*. Pair it with `ISB` whenever the system-register change also affects how subsequent instructions execute (enabling the MPU, changing CONTROL, changing VTOR).

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

### Example 1 — pend PendSV from thread code, then sleep

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

### Example 2 — relocate the vector table (DSB then ISB)

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Move the vector table into RAM and switch to it
    ldr     r0, =0xE000ED08         @ SCB->VTOR
    ldr     r1, =new_vectors
    str     r1, [r0]                @ install new VTOR
    dsb                             @ ensure SCB sees the write
    isb                             @ refetch with the new vector base
    @ from here, any exception uses new_vectors
loop:
    b   loop

    .section .rodata
    .balign 512
new_vectors:
    .word 0x20008000                @ initial MSP
    .word reset_handler + 1         @ Reset
```

**Walkthrough:**

1. `str r1, [r0]` — write the new VTOR.
2. `dsb` — *do not skip*. Without it the SCB write may still be in the write buffer when the next exception fires; the CPU could still vector through the old table.
3. `isb` — flush the prefetch so any subsequent exception that the pipeline already started speculating about uses the new vector base. The `DSB; ISB` pair is the canonical recipe after every system-register change that affects how subsequent code or exceptions run. `DMB` would be wrong here: it orders memory but doesn't wait for the SCB write to complete.

## See also

- [DMB](DMB.md) — orders accesses without stalling completion
- [ISB](ISB.md) — flushes the pipeline; usually pair `DSB; ISB`
- [WFI](WFI.md), [WFE](WFE.md) — common sites for a preceding DSB

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.50 — *DSB*.
