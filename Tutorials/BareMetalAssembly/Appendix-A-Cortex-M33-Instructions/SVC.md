# SVC — supervisor call; raise the SVCall exception

## Class & availability

- **Class:** System
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None — designed to be called *from* unprivileged code to enter privileged code
- **Secure-state required:** No (in TrustZone systems, SVC banks per security state)

## Synopsis

```text
SVC #<imm8>            @ imm8 = 0..255, available to the handler in the instruction stream
```

**When you'd actually use this** — `SVC` is the canonical user-mode → privileged-mode entry point: an unprivileged thread executes `SVC #n`, the SVCall exception fires, and `SVC_Handler` runs in privileged mode with the caller's `R0..R3` already on the stack. RTOSes (FreeRTOS, Zephyr) use it to deliver kernel services like `xQueueSend` from unprivileged tasks, and bare-metal firmware uses it to expose a syscall ABI between an application image and a privileged "kernel" image. The immediate is *not* delivered in a register — the handler reads `[stacked_PC] - 2` to recover it. Beware: if SVCall priority is lower than current execution priority (e.g. you're already in an ISR), the SVC escalates to HardFault — which is why `SVC` is rare from inside an ISR.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<imm8>` | 8-bit immediate | `0..255`. The hardware does not pass this to the handler in any register — the handler must fetch it by reading `[stacked_PC] - 2` and masking the low byte. |

## Operation (pseudocode)

```text
// Synchronous exception. The processor:
//   1. stacks {R0-R3, R12, LR, ReturnAddress, xPSR} on the active stack
//   2. takes the SVCall exception (vector index 11)
//   3. enters Handler mode at SVC_Handler with the stacked context
// SVC priority is configurable via SHPR2; if it is masked by
// PRIMASK or BASEPRI at higher priority, escalating SVC causes a
// HardFault (this is the "SVC inside a critical section" gotcha).
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags directly. The handler may, of course.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `1101 1111 iiii iiii` (`DFxx`) |

No 32-bit form.

## Exceptions / faults

- Raises **SVCall** (exception #11). Becomes a HardFault if SVCall is masked when the SVC executes.

## Example

### Example 1 — syscall #1 with an immediate-decoding handler

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .global  SVC_Handler
    .thumb_func
reset_handler:
    @ Ask the OS to do something privileged via syscall #1
    movs    r0, #42
    svc     #1                  @ trap into SVC_Handler with imm8=1
    @ on return, r0 holds whatever the handler put there
loop:
    b   loop

    .thumb_func
SVC_Handler:
    @ Recover the imm8 from the stacked PC (R0..xPSR were pushed)
    mrs     r1, msp             @ assume came from MSP for simplicity
    ldr     r2, [r1, #24]       @ stacked ReturnAddress (PC)
    ldrb    r2, [r2, #-2]       @ low byte of the SVC instruction = imm8
    @ dispatch on r2 here; for the demo just double r0 on the stack
    ldr     r3, [r1, #0]        @ stacked R0
    lsls    r3, r3, #1
    str     r3, [r1, #0]        @ overwrite stacked R0 = return value
    bx      lr                  @ EXC_RETURN — pops the frame
```

**Walkthrough:**

1. `svc #1` — synchronous exception. R0..xPSR are auto-stacked; LR becomes an EXC_RETURN code.
2. `SVC_Handler` reads the stacked PC, steps back two bytes, and reads the immediate so it can dispatch on it.
3. Modifying the stacked R0 changes the value the caller sees in R0 after `bx lr` pops the frame — this is how syscalls return values on Arm-M.

This is the part that bites people: if SVCall priority is set lower than the priority you're currently running at, the SVC will *escalate to HardFault*. Don't call `SVC` from inside an ISR unless you've done the priority math.

### Example 2 — FreeRTOS-style "start scheduler" trampoline

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .global  SVC_Handler
    .thumb_func
reset_handler:
    @ Bootstrap the kernel: SVC #0 traps into the privileged starter
    @ which sets up PSP/CONTROL and jumps to the first task.
    svc     #0                      @ kernel takes over
    b       .                       @ never returns
loop:
    b   loop

    .thumb_func
SVC_Handler:
    @ Demo: real handler would dispatch on imm8 and start the scheduler
    bx      lr
```

**Walkthrough:**

1. `svc #0` — synchronous exception. R0..xPSR are auto-stacked; LR becomes an EXC_RETURN code.
2. `SVC_Handler` runs in privileged mode. In a real RTOS this is where the kernel parses the immediate (via the stacked PC), restores the first task's context, and `bx lr` returns into thread mode using PSP. The thread never sees `b .` execute — control flow effectively pivots through the handler.

## See also

- [BKPT](BKPT.md) — synchronous trap into the debugger, not into SVC_Handler
- [UDF](UDF.md) — synchronous trap into UsageFault
- [MRS](MRS.md), [MSR](MSR.md) — read/write the stack pointers from inside the handler

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.196 — *SVC*.
