# DBG — debug hint; pass a 4-bit value to the debug architecture

## Class & availability

- **Class:** Hint
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
DBG #<option>          @ <option> is a 4-bit immediate, 0..15
```

**When you'd actually use this** — almost never on the Nano Matter. `DBG #imm` is a hint to the debug architecture; on Cortex-M33 it executes as a NOP at runtime but its encoding survives in disassembly so external trace tooling (ETM, ITM postprocessors) can recognise the marker. If you actually want to emit trace markers from running code, the ITM stimulus port (`ITM->PORT[n]`) is far more useful and observable from a SWD debugger — `DBG` is mostly a portability artefact you'll see when reading code written for other Arm cores.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<option>` | 4-bit immediate | `0..15`, meaning is IMPLEMENTATION DEFINED |

## Operation (pseudocode)

```text
// Architecturally a hint to the debug system. The implementation
// is free to ignore it. Cortex-M33 does not act on DBG — it
// executes as a NOP on the Nano Matter. The encoding is preserved
// so external trace tooling can recognise it in disassembly.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1111 0011 1010 1111 1000 0000 1111 oooo` (`F3AF 80Fo`, where `o` is the option) |

No 16-bit form.

## Exceptions / faults

- (none).

## Example

### Example 1 — bracket a measured region with DBG markers

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Mark a region of code with a debug hint visible in trace
    movs    r0, #0
    dbg     #0              @ "entering measured region"
    bl      do_work
    dbg     #1              @ "leaving measured region"
loop:
    b   loop

do_work:
    adds    r0, r0, #1
    bx      lr
```

**Walkthrough:**

1. `dbg #0` — emits the encoding into the instruction stream; on the M33 it's a NOP at runtime but a tracer can pick it out.
2. `bl do_work` — the work being measured.
3. `dbg #1` — closing marker.

In practice, on the Nano Matter you'll get more mileage from the ITM (`STIM` registers) for trace markers. `DBG` is mostly a portability artefact — keep it in mind when reading disassembly from other Arm cores.

### Example 2 — bracket a critical section for ETM dwell-time analysis

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Surround a critical region with DBG markers so an ETM trace
    @ tool can later compute the dwell time precisely
    dbg     #2                      @ "critical-region begin"
    cpsid   i
    @ … RMW on shared state …
    cpsie   i
    dbg     #3                      @ "critical-region end"
loop:
    b   loop
```

**Walkthrough:**

1. `dbg #2` — encoded into the stream; on M33 it's a runtime NOP but ETM tooling can spot the encoding and timestamp it.
2. The actual critical section (`cpsid i` … `cpsie i`).
3. `dbg #3` — closing marker. With both timestamps the trace tool can report exact dwell time without instrumentation overhead. In practice you'd reach for the ITM stimulus port instead — it's observable live over SWO — and `DBG` stays as a curiosity.

## See also

- [NOP](NOP.md) — what DBG executes as on this chip
- [BKPT](BKPT.md) — actually halt the core under a debugger

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.39 — *DBG*.
