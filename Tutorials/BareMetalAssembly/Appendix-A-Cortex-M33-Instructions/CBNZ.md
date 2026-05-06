# CBNZ — compare and branch forward if register is non-zero

## Class & availability

- **Class:** Branch
- **Architecture:** ARMv8-M Mainline (base)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** No

## Synopsis

```text
CBNZ   <Rn>, <label>
```

**When you'd actually use this**: `CBNZ` collapses the very common `CMP Rn,#0; BNE label` pair into a single 16-bit instruction without disturbing flags — exactly what compilers want for non-null-handle guards, "did we find a hit?" branches after a search, and end-of-loop probes that mustn't clobber `Z`/`N`/`C`/`V`. Two restrictions bite: it's forward-only (you cannot use it to close a backward loop), and the immediate is 0–126 bytes, so a careless refactor can put your label out of reach. When that happens the assembler complains and you fall back to `cmp`/`bne`.

`CBNZ` is the mirror of `CBZ`: branch **forward** to `<label>` iff `<Rn>` is non-zero. Same restrictions apply:

- forward-only (range 0–126 bytes from the current PC);
- low registers only (`r0`–`r7`);
- does **not** read or write APSR.

This is the part that bites people: `CBNZ` can never close a backward loop. The encoded immediate is unsigned. To loop, use `subs`+`bne` (or `bne` after any flag-setting instruction). `CBNZ`'s sweet spot is *skipping a fall-through block when a register is non-zero* — typically jumping over an error/cleanup path to a "valid handle" path.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rn>` | tested register | one of `r0`–`r7` |
| `<label>` | forward target | range +0 to +126 bytes from PC, halfword-aligned |

## Operation (pseudocode)

```text
if Rn != 0 then
    PC = PC + zero_extend(imm)   // forward only
// flags are NEVER updated
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `CBNZ <Rn>, <label>` — only encoding |

## Exceptions / faults

- (none)

## Example

### Example 1 — skip error path on valid handle

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ CBNZ demo: skip the error path when the handle is valid.
    movs    r0, #7              @ pretend handle (non-zero = valid)
    bl      use_handle
    @ r0 = 14 on the valid path, -1 on the null path
loop:
    b       loop

    .thumb_func
use_handle:
    cbnz    r0, .Lvalid         @ jump forward when handle != 0
    movs    r0, #-1             @ null path: return error code
    bx      lr
.Lvalid:
    lsls    r0, r0, #1          @ valid path: do the real work (×2)
    bx      lr
```

**Walkthrough:**

1. `cbnz r0, .Lvalid` — if `r0` is non-zero, skip directly past the error path. No APSR flags are read or written.
2. `movs r0, #-1` — only executed when `r0` was zero on entry; sets the error return.
3. `bx lr` — early return for the null case.
4. `.Lvalid:` `lsls r0, r0, #1` — the work the function actually wants to do when given a valid handle.
5. `bx lr` — return from the happy path.

The whole guard collapses into one 16-bit instruction. A `cmp r0, #0` + `bne .Lvalid` would do the same, but two instructions and would clobber `Z`, `N`, `C`, `V`.

### Example 2 — branchless flag select

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    movs    r0, #5          @ pretend "count"
    cbnz    r0, .Lnonzero   @ forward jump when r0 != 0
    movs    r1, #0          @ count was zero
    b       loop
.Lnonzero:
    movs    r1, #1          @ count was non-zero
loop:
    b       loop
```

**Walkthrough:**

1. `cbnz r0, .Lnonzero` — single-instruction test-and-skip. APSR untouched.
2. `movs r1, #0` — runs only when `r0` was zero.
3. `.Lnonzero: movs r1, #1` — runs only when `r0` was non-zero.
4. The whole thing is one 16-bit `CBNZ` plus two `MOVS` — three halfwords total versus four for the `cmp`/`bne` equivalent.

## See also

- [CBZ](CBZ.md) — opposite sense (branch when zero).
- [B](B.md) — supports backward branches and conditions other than zero/non-zero.
- [IT](IT.md) — gate one or more instructions without branching at all.

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.22 — *CBNZ, CBZ*.
