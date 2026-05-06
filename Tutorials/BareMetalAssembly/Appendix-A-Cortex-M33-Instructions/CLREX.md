# CLREX — clear the local exclusive monitor

## Class & availability

- **Class:** Data movement
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
CLREX
```

Drops any outstanding reservation set by [`LDREX`](LDREX.md), [`LDREXB`](LDREXB.md), [`LDREXH`](LDREXH.md), or their acquire-semantic siblings ([`LDAEX`](LDAEX.md) etc.). No operands. Cannot fault.

**When you'd actually use this** an RTOS context-switch path forcibly drops any reservation a thread had armed via `LDREX` so that, when a *different* thread is resumed, its first `STREX` cannot spuriously succeed against a stale monitor. The architecture already does an implicit clear on exception entry/exit, but `CLREX` is the explicit form used inside fault handlers that abort an in-progress LDREX/STREX retry, and on the bail-out path of a CAS that decided not to commit. Without it you'd lean on side-effects (next `LDREX`, next exception) to drop the reservation — correct but obscure to reviewers.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| _(none)_ | — | `CLREX` takes no operands. |

## Operation (pseudocode)

```text
ClearExclusiveLocal();
@ Flags unchanged.
```

The exception model already executes a CLREX-equivalent on entry to and return from any exception, so user code rarely needs explicit `CLREX` — it's mostly used when bailing out of a CAS-style sequence without committing.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width  | Form          |
|---------|--------|---------------|
| T1      | 32-bit | `CLREX` — only encoding. |

## Exceptions / faults

- (none).

## Example

### Example 1 — CAS bail-out drops monitor

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ CAS-style bail: read with LDREX, decide to abort, drop the monitor.
    ldr     r0, =cell
    movw    r3, #0xDEAD             @ sentinel "do not touch" value
    ldrex   r1, [r0]                @ arm monitor
    cmp     r1, r3
    beq     abort                   @ leave memory unchanged...
    adds    r1, r1, #1
    strex   r2, r1, [r0]            @ ...else commit
    b       done
abort:
    clrex                           @ release reservation explicitly
done:
loop:
    b       loop

    .data
    .align  2
cell:
    .word   1
```

**Walkthrough:**

1. `ldrex r1, [r0]` — arms the monitor for the address.
2. The `cmp` / `beq` decides whether to commit. On the abort path, no `STREX` will be issued.
3. `clrex` — explicitly clears the local reservation so it doesn't sit armed any longer than necessary. This is the part that bites people: it is *correct* to omit `CLREX` on the abort path — the monitor will be cleared on the next exception or the next `LDREX`/`STREX` — but `CLREX` makes the intent obvious to a code reviewer and avoids subtle interactions on multi-master buses.

### Example 2 — Switch monitor between two cells

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Sequence A: read cell_a exclusively, then realise we want cell_b instead.
    ldr     r0, =cell_a
    ldr     r1, =cell_b
    ldrex   r2, [r0]                @ monitor armed for cell_a
    clrex                           @ drop it before starting unrelated work
    ldrex   r3, [r1]                @ now arm for cell_b cleanly
    adds    r3, r3, #1
    strex   r4, r3, [r1]            @ commit on cell_b
loop:
    b       loop

    .data
    .align  2
cell_a:
    .word   0
cell_b:
    .word   0
```

**Walkthrough:**

1. First `LDREX` arms the monitor on `cell_a`; we then change our mind.
2. `CLREX` explicitly drops the `cell_a` reservation so the second `LDREX` starts from a clean state.
3. Without `CLREX` the second `LDREX` would also arm correctly (it overwrites the reservation), but mixing two reservations across an interrupt boundary is exactly the scenario where a leftover armed monitor causes head-scratching debug sessions.

## See also

- [LDREX](LDREX.md) / [LDREXB](LDREXB.md) / [LDREXH](LDREXH.md) — instructions that *set* the monitor.
- [STREX](STREX.md) / [STREXB](STREXB.md) / [STREXH](STREXH.md) — committing stores; failure also clears the monitor.
- [DMB](DMB.md) — for ordering (different concept; CLREX does not imply a barrier).

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.13 — *CLREX*.
