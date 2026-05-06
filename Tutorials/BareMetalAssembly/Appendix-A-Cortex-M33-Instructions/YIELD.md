# YIELD — hint that this thread is in a spin and could be descheduled

## Class & availability

- **Class:** Hint
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
YIELD
```

**When you'd actually use this** — `YIELD` is a portability hint: on multi-threaded implementations it tells the implementation "I'm spinning, please run someone else", and on the bare-metal M33 it's architecturally a NOP. Sprinkle it into the back-off path of `LDREX`/`STREX` retry loops and software spinlocks as RTOS-portability hygiene; if the code ever moves to a hyperthreaded host or an OS that hooks `YIELD`, you get descheduling for free. It does **not** save power — for that, use `WFE` so the core actually goes to sleep. Treat `YIELD` as documentation of intent more than an instruction with teeth.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| (none) | — | YIELD takes no operands |

## Operation (pseudocode)

```text
// Hint that the current task is doing nothing useful (typically a
// spinlock or busy-wait) and another thread, if any, could run.
// On bare-metal Cortex-M33 with no SMT/hyperthreading and no OS
// hook, this executes as a NOP. An RTOS may trap it via a fault
// handler or simply ignore it.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `1011 1111 0001 0000` (`BF10`) |
| T2 | 32-bit | `1111 0011 1010 1111 1000 0000 0000 0001` (`F3AF 8001`) |

## Exceptions / faults

- (none).

## Example

### Example 1 — YIELD inside a flag-polling spin

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Spin on a flag set by an ISR, hinting we're idle in the loop
    ldr     r0, =g_flag
1:  ldr     r1, [r0]
    cbnz    r1, 2f
    yield                   @ "I'm just spinning" — NOP on bare M33
    b       1b
2:  @ flag is set, proceed
loop:
    b   loop

    .data
g_flag: .word 0
```

**Walkthrough:**

1. `ldr r1, [r0]` — sample the shared flag.
2. `cbnz r1, 2f` — exit the spin once it goes non-zero.
3. `yield` — hint to the implementation. On the Nano Matter's M33 it's architecturally a NOP, but it documents intent and is free to keep around if the code ever moves to an RTOS that hooks it.

For real power savings on this chip, prefer `WFE`/`WFI` — `YIELD` does **not** reduce current.

### Example 2 — RTOS-portable LDREX/STREX try-lock

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Try-lock: LDREX/STREX with YIELD between attempts so an
    @ RTOS that hooks YIELD can deschedule us during contention
    ldr     r0, =g_lock
1:  ldrex   r1, [r0]
    cbnz    r1, 2f                  @ already held?
    movs    r2, #1
    strex   r3, r2, [r0]            @ try to take it
    cbz     r3, 3f                  @ success
2:  yield                           @ contended — hint we'd like to be paused
    b       1b
3:  @ critical section here
loop:
    b   loop

    .data
    .align 2
g_lock: .word 0
```

**Walkthrough:**

1. `ldrex` reads the lock word and arms the exclusive monitor.
2. `cbnz` skips to the back-off path if it's already held.
3. `strex` attempts to commit `1` atomically; non-zero result = lost the race.
4. `yield` — on bare-metal M33 this is a NOP and we just spin, but if this binary ever runs on a hyperthreaded core or under an RTOS that hooks YIELD, contention back-off becomes free.

## See also

- [NOP](NOP.md) — what YIELD effectively is on bare-metal M33
- [WFE](WFE.md) — actually sleep instead of spinning
- [WFI](WFI.md) — sleep until an interrupt

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.319 — *YIELD*.
