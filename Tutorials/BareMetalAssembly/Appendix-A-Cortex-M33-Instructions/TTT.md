# TTT — Test Target with T-flag (unprivileged view)

TrustZone for Armv8-M splits the chip into **Secure** and **Non-secure** worlds. `TTT` is the **T-flag** variant of [TT](TT.md): it asks the SAU/IDAU/MPU what would happen for an access at the probed address **as if performed unprivileged**, regardless of the probing code's actual privilege level. Privileged Secure code uses this to validate pointers on behalf of an unprivileged caller — "would *they* be allowed to touch this?"

## Class & availability

- **Class:** Security (System query)
- **Architecture:** ARMv8-M + Security
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None to execute, but only meaningful when called from privileged code (otherwise behaves like `TT`).
- **Secure-state required:** No — queries the **current** security state, just like `TT`.

## Synopsis

```text
TTT  <Rd>, <Rn>
```

Same shape as `TT`. The encoding sets the **T** bit so the MPU lookup uses unprivileged permissions.

**When you'd actually use this:** `TTT` is `TT` with the **T-flag** asserted, so the MPU permissions reported in the result reflect what an *unprivileged* thread could do — even when the probing code is privileged. On the Arduino Nano Matter this matters whenever a privileged Secure handler (an SVC dispatcher inside the Silicon Labs Secure Library, say) is validating a pointer on behalf of an unprivileged Secure thread, or — paired with the **A-flag** as `TTAT` — on behalf of unprivileged Non-secure code. Plain `TT` would lie: it would say "yes, accessible" based on the validator's own privilege, then the real access from the unprivileged caller would fault. `TTT` makes the validator honest, and its result word also carries the readability/Thumb-bit information you need before an indirect call to a candidate function pointer.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register (result word) | R0–R12, R14. PC/SP UNPREDICTABLE. |
| `<Rn>` | register holding address to probe | R0–R12, R14. PC/SP UNPREDICTABLE. |

## Operation (pseudocode)

```text
addr     = Rn
sec      = CurrentSecurityState()
priv     = Unprivileged           @ <-- this is what T-flag forces
mpu      = MPU_LookUp(addr, sec, priv)
sau/idau = same as TT
Rd       = AttributionWord(mpu, sau, idau)
                                  @ also sets bit 30 ("T") in result so
                                  @ readers can tell this was a TTT probe
```

The SAU/IDAU answer (Secure/Non-secure/NSC) is *not* affected by the T-flag — security attribution is independent of privilege. Only the MPU read/write permission bits in the result change.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates APSR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1110 1000 0100 Rn 1111 Rd 0100 0000` (TT-family with T=1, A=0) |

## Exceptions / faults

- `(none)` — like all TT-family instructions, `TTT` performs no memory access and never faults on the probed address.

## Example

### Example 1 — Range check for an unprivileged caller's buffer

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    @ Illustrative — full use requires a CMSE-enabled toolchain build.

    .text
    .global  syscall_validate_buf
    .thumb_func
syscall_validate_buf:
    @ Privileged Secure handler validating a buffer on behalf of an
    @ unprivileged Secure thread.
    @ r0 = base, r1 = length (>0). Returns r0 = 1 if the *unprivileged*
    @ caller could read the whole range, else 0.
    adds    r2, r0, r1
    subs    r2, r2, #1          @ r2 = last byte address
    ttt     r3, r0              @ probe first byte (unprivileged view)
    ttt     r12, r2             @ probe last byte (unprivileged view)
    eors    r3, r3, r12
    lsrs    r3, r3, #8          @ same SAU+MPU region in both probes?
    movs    r0, #0
    it      eq
    moveq   r0, #1
    bx      lr
loop:
    b       loop
```

**Walkthrough:**

1. `adds`/`subs` — compute the address of the buffer's last byte.
2. `ttt r3, r0` — probe the *first* byte's attributes using **unprivileged** permissions. Bit 22 will tell you it's Non-secure (or not), the MPU bits will tell you whether unprivileged code can read it.
3. `ttt r12, r2` — probe the *last* byte. Both must land in the same SAU and MPU region; if they don't, the buffer crosses a boundary and must be rejected.
4. `eors`/`lsrs` — compare the two attribution words ignoring the low byte (which is the MPU region number; the SAU region is in the second byte). Equal results = consistent region.
5. `it eq` / `moveq r0, #1` — set the boolean return.

This is the part that bites people: privileged Secure code that uses plain [TT](TT.md) here will get a "yes, accessible" answer based on its *own* privilege, then later the actual access from the unprivileged thread faults. `TTT` is what makes the validator honest.

### Example 2 — TTT vetting an indirect-call target

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Illustrative — full use requires a CMSE-enabled toolchain build.
    @ TTT demo 2: vet a code pointer for an unprivileged caller before BLX.
    @ r0 = candidate function pointer (Thumb bit set as usual).
    bic     r1, r0, #1          @ probe address without the T-bit
    ttt     r2, r1              @ unprivileged-view attribution
    lsrs    r3, r2, #23
    ands    r3, r3, #1          @ bit 23: readable from current state (unpriv)
    beq     .Lreject
    blx     r0                  @ ok: indirect call (Thumb bit preserved in r0)
    b       loop
.Lreject:
    movs    r0, #0
loop:
    b       loop
```

**Walkthrough:** A privileged Secure dispatcher receives a function pointer that an *unprivileged* thread asked it to call. We strip the Thumb bit before probing (the SAU/MPU don't care about T), then `ttt` reports what the unprivileged thread itself would see. If the location isn't readable from unprivileged state we refuse; otherwise the original `r0` (with its Thumb bit intact) feeds straight into `blx`. Plain `TT` here would happily greenlight memory only the privileged dispatcher can reach, then `BLX` would fault when actually executing — `TTT` keeps the validator and the eventual access in agreement.

## See also

- [TT](TT.md) — base form (current privilege)
- [TTA](TTA.md) — alternate (Non-secure) domain probe
- [TTAT](TTAT.md) — alternate domain + T-flag
- [SG](SG.md) / [BXNS](BXNS.md) / [BLXNS](BLXNS.md) — the boundary-crossing instructions whose pointers you are validating

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.351 — *TT, TTT, TTA, TTAT*.
