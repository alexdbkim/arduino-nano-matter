# WFI — wait for interrupt; halt the core until an exception wakes it

## Class & availability

- **Class:** Hint
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None (but typically used in privileged code; effect can be gated by `SCR.SLEEPDEEP` and the chip's EMU)
- **Secure-state required:** No

## Synopsis

```text
WFI
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| (none) | — | WFI takes no operands |

## Operation (pseudocode)

```text
// Suspend execution. The core enters a low-power state (EM1/EM2/…
// on EFR32MG24, selected by SCR.SLEEPDEEP and EMU registers) and
// stays there until any of:
//   - an IRQ becomes pending and is enabled at the NVIC (priority
//     high enough to preempt; or any IRQ if PRIMASK is set — PRIMASK
//     does NOT prevent WFI from waking)
//   - a debug event
//   - an asynchronous reset
// On wake the pipeline restarts from the instruction after WFI.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `1011 1111 0011 0000` (`BF30`) |
| T2 | 32-bit | `1111 0011 1010 1111 1000 0000 0000 0011` (`F3AF 8003`) |

## Exceptions / faults

- (none) directly. The wake-up path *does* take whatever exception became pending.
- If `PRIMASK = 1` you wake but the IRQ stays masked — re-enable it (`CPSIE i`) to actually service it.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Idle loop: do work, then sleep until the next interrupt
    bl      do_work
    dsb                     @ make sure all memory writes retire
    wfi                     @ sleep — SysTick / GPIO / radio IRQ wakes us
    b       reset_handler
loop:
    b   loop
```

**Walkthrough:**

1. `bl do_work` — placeholder for the foreground task.
2. `dsb` — drains the write buffer; without it a peripheral write that arms a wake source could still be in flight when we sleep.
3. `wfi` — core halts; current draw drops to EM1/EM2 levels until an IRQ fires.
4. `b reset_handler` — after waking, loop and sleep again. This is the canonical tickless-idle shape.

This is the part that bites people: `WFI` may return *immediately* if an IRQ is already pending when you execute it. That's by design — always treat WFI as a hint and re-check your wake condition.

## See also

- [WFE](WFE.md) — sleep on the Event Register, not on IRQs alone
- [SEV](SEV.md) — wake a core that's in WFE
- [DSB](DSB.md) — pair before WFI when the wake-up depends on a memory write
- [CPSID](CPSID.md), [CPSIE](CPSIE.md) — interaction with PRIMASK

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.310 — *WFI*.
