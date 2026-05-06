# UDF — permanently undefined; always raises a UsageFault

## Class & availability

- **Class:** System
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
UDF{.W} #<imm>         @ T1: imm 0..255   T2: imm 0..65535
```

**When you'd actually use this** — `UDF` is *guaranteed-undefined-forever*: the encoding will never be repurposed, so it's the architecturally clean way to mark unreachable code, switch-default cases, integer-overflow traps (the back-end of `-ftrapv`), or deliberate fault-injection for firmware tests. Unlike `BKPT` it behaves identically with or without a debugger — always a UsageFault (escalating to HardFault if `SHCSR.USGFAULTENA = 0`) — which makes it the right choice for `assert(0)` in shipping firmware. The 16-bit immediate has no architectural meaning but is readable from the faulting PC, so you can use it as a numeric tag to disambiguate which `UDF` site fired.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<imm>` | immediate | T1: `0..255`, T2: `0..65535`. Architecturally ignored; useful as a tag readable from the faulting PC. |

## Operation (pseudocode)

```text
// The encoding is explicitly defined to be UNDEFINED, forever.
// The processor takes a UsageFault with CFSR.UFSR.UNDEFINSTR = 1.
// If UsageFault is disabled (SHCSR.USGFAULTENA = 0) it escalates
// to HardFault. Future architecture revisions are guaranteed not
// to repurpose this encoding.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags (it never retires normally).

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `1101 1110 iiii iiii` (`DExx`) |
| T2 | 32-bit | `1111 0111 1111 iiii 1010 iiii iiii iiii` (`F7Fx Axxx`) |

The T2 form is mostly used by linkers/compilers that want a 32-bit "trap" they can't accidentally fall *into* from a 16-bit predecessor.

## Exceptions / faults

- **UsageFault** with `UFSR.UNDEFINSTR = 1`, escalating to HardFault if UsageFault is not enabled in `SHCSR`.

## Example

### Example 1 — unreachable-dispatch trap

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Dispatch table — anything outside [0,2] is unreachable
    movs    r0, #3                  @ pretend bad input
    cmp     r0, #2
    bhi     unreachable
    @ ... real dispatch here ...
    b       done

unreachable:
    udf     #0xAB                   @ assert(0): tag 0xAB visible at the faulting PC

done:
loop:
    b   loop
```

**Walkthrough:**

1. The `cmp` / `bhi` validates the dispatch index.
2. Falling into `unreachable` indicates a bug; `udf #0xAB` raises a UsageFault. The fault handler can read the stacked PC, fetch the halfword there, and recover the `#0xAB` tag for diagnostics.
3. Unlike `BKPT`, `UDF` behaves identically with or without a debugger — making it the right choice for `assert(0)`-style traps in shipping firmware.

This is the part that bites people: if you haven't enabled UsageFault (`SHCSR.USGFAULTENA = 1`), `UDF` will land you in HardFault, which has less informative status registers — enable UsageFault during bring-up so you actually see `UNDEFINSTR`.

### Example 2 — switch-default trap in shipping firmware

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ switch (cmd) { case 0..2: …; default: unreachable }
    movs    r0, #4                  @ "out of range" input
    cmp     r0, #2
    bls     case_ok
    udf     #0xDE                   @ tag 0xDE in UFSR for triage
case_ok:
    @ valid case handler here
loop:
    b   loop
```

**Walkthrough:**

1. `cmp` / `bls` accept inputs 0..2.
2. Out-of-range inputs fall into `udf #0xDE`. The fault handler can read the halfword at the stacked PC, mask the low byte, and recover `0xDE` to know exactly which `UDF` fired. Versus `BKPT` here: `UDF` is the right shipping choice because it produces a UsageFault on a board *without* a debugger too — `BKPT` would HardFault with a vague status code instead.

## See also

- [BKPT](BKPT.md) — debugger-aware halt; not appropriate for release `assert(0)`
- [SVC](SVC.md) — synchronous trap into SVC_Handler, not a fault

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.293 — *UDF*.
