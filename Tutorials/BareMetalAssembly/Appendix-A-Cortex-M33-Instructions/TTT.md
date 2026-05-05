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

## See also

- [TT](TT.md) — base form (current privilege)
- [TTA](TTA.md) — alternate (Non-secure) domain probe
- [TTAT](TTAT.md) — alternate domain + T-flag
- [SG](SG.md) / [BXNS](BXNS.md) / [BLXNS](BLXNS.md) — the boundary-crossing instructions whose pointers you are validating

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.351 — *TT, TTT, TTA, TTAT*.
