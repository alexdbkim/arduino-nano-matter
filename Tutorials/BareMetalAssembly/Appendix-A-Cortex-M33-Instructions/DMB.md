# DMB — data memory barrier; order memory accesses without stalling

## Class & availability

- **Class:** System (barrier)
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
DMB {<option>}         @ option defaults to SY
```

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<option>` | barrier domain | `SY` (full system, default), `ST`, `ISH`/`ISHST`, `NSH`/`NSHST`, `OSH`/`OSHST`. On a single-core M33 these mostly collapse to the same behaviour as `SY`. |

## Operation (pseudocode)

```text
// Guarantee that every explicit memory access *before* the DMB is
// observed by every observer in the shareability domain *before*
// any explicit memory access *after* the DMB. The core itself is
// not stalled — it can keep executing — but the ordering as seen
// from a DMA engine, the debugger, or another bus master is
// preserved.
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates flags.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1111 0011 1011 1111 1000 1111 0101 ssss` (`F3BF 8F5s`, `s` = option) |

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
    @ Hand off a buffer to a DMA channel: fill, then publish the
    @ "ready" flag. DMA must see fill BEFORE the flag flip.
    ldr     r0, =g_buf
    movs    r1, #0xAA
    strb    r1, [r0, #0]
    strb    r1, [r0, #1]
    strb    r1, [r0, #2]
    strb    r1, [r0, #3]
    dmb                     @ orders all the strbs before the flag store
    ldr     r2, =g_ready
    movs    r3, #1
    str     r3, [r2]
loop:
    b   loop

    .data
    .align 2
g_buf:   .skip 4
g_ready: .word 0
```

**Walkthrough:**

1. Four `strb` writes populate the buffer.
2. `dmb` — without it, a DMA master polling `g_ready` could see the flag come up while the buffer bytes are still in the write buffer.
3. The flag store publishes the buffer.

Rule of thumb: use `DMB` for *ordering* between two memory regions visible to multiple observers (CPU + DMA, CPU + debugger). Use `DSB` when you also need the first access to be **complete** before continuing (e.g. before `WFI` or `MSR CONTROL`). Use `ISB` to flush the pipeline.

## See also

- [DSB](DSB.md) — stronger barrier that also waits for completion
- [ISB](ISB.md) — pipeline flush, complements DSB after context changes
- [LDREX](LDREX.md), [STREX](STREX.md) — the other half of lock-free hand-offs

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.49 — *DMB*.
