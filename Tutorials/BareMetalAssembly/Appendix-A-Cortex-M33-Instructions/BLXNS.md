# BLXNS — Branch with Link and eXchange to Non-Secure

TrustZone for Armv8-M splits the chip into **Secure** and **Non-secure** worlds. When Secure code needs to *call* a Non-secure function (e.g. a callback registered by Non-secure firmware) it must use `BLXNS`. A plain `BLX` would either fault or, worse, run Non-secure code with Secure privileges. `BLXNS` performs the call, switches the CPU to Non-secure state, and stashes a Secure-only return token so the matching return can come back safely.

## Class & availability

- **Class:** Security (Branch)
- **Architecture:** ARMv8-M + Security
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** Yes — UNDEFINED in Non-secure state.

## Synopsis

```text
BLXNS  <Rm>
```

`Rm` holds the call target. Bit[0] of `Rm` selects the destination security state: **0 = Non-secure** (the normal case), 1 = stay Secure (acts like `BLX`).

**When you'd actually use this:** `BLXNS` is for Secure code that needs to **call out** to Non-secure code and resume Secure execution afterwards. The textbook Arduino Nano Matter case is the Silicon Labs Secure Library invoking a Non-secure-supplied callback — for example, an event hook the Matter stack registered with secure boot or with the attestation service. The architecture stashes the Secure return address in a hardware-managed frame on the Secure stack and replaces `LR` with the non-dereferenceable `FNC_RETURN` token, so the Non-secure side cannot *forge* a return into the middle of a secure routine. Without `BLXNS` you'd either fault outright or, more dangerously, run Non-secure code with Secure privileges — exactly the sort of bug that turns a callback API into a complete TrustZone bypass.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rm>` | source register holding target address | R0–R14. PC (R15) is UNPREDICTABLE. SP is UNPREDICTABLE. |

## Operation (pseudocode)

```text
if CurrentSecurityState() != Secure then UNDEFINED;
target = Rm AND 0xFFFFFFFE
to_NS  = (Rm[0] == '0')
if to_NS then
    @ Save Secure return state in a hardware-managed structure on the
    @ Secure stack, then place a non-dereferenceable token in LR.
    PushSecureReturnFrame()
    LR = FNC_RETURN              @ 0xFEFFFFFF-style magic value
    ScrubCallerSavedRegisters()  @ avoid leaking Secure data
    SwitchToNonSecureState()
else
    LR = (PC_of_next_instr) | 1  @ behave like BLX (no state change)
PC = target
```

When the Non-secure callee later does `BX LR`, the magic `FNC_RETURN` value triggers the hardware to pop the saved Secure frame and resume Secure execution — that is the round-trip.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates APSR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `0100 0111 1 Rm 100` (closely related to `BLX <Rm>`; distinguished by the low bits) |

## Exceptions / faults

- **UNDEFINED** in Non-secure state → UsageFault (UNDEFINSTR).
- **SecureFault (INVTRAN)** if `Rm` claims Non-secure (bit[0]=0) but the SAU/IDAU says the target is Secure.
- **SecureFault** on stack push failure (e.g. Secure stack overflow) when saving the return frame.

## Example

### Example 1 — Secure code invoking a Non-secure callback

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    @ Illustrative — full use requires a CMSE-enabled toolchain build.
    @ The Non-secure callback pointer is validated with TT/TTA before use.

    .text
    .global  secure_call_ns_callback
    .thumb_func
secure_call_ns_callback:
    @ r0 = pointer to a Non-secure callback, r1 = argument to pass
    bic     r0, r0, #1          @ force bit[0] = 0 (Non-secure target)
    mov     r12, r0
    mov     r0, r1              @ argument in r0 per AAPCS
    blxns   r12                 @ call Non-secure; returns here in Secure
    @ on return, r0 holds the Non-secure callback's result
    bx      lr                  @ ordinary Secure-to-Secure return
loop:
    b       loop
```

**Walkthrough:**

1. `bic r0, r0, #1` — clear bit[0]; this is the security indicator, *not* a Thumb bit. We need it 0 so `BLXNS` actually transitions to Non-secure state.
2. `mov r12, r0` / `mov r0, r1` — move target into a scratch register and put the real argument into `r0` per the AAPCS.
3. `blxns r12` — pushes a Secure return frame, replaces `LR` with the `FNC_RETURN` magic token, scrubs caller-saved registers so Secure data does not leak, and continues execution in Non-secure state at the callback.
4. When the Non-secure callback runs `BX LR`, the hardware sees the magic value, restores the Secure frame, and we resume *here* with `r0` = the callback's return value.
5. `bx lr` — plain return to whoever called us inside Secure code.

This is the part that bites people: callers must validate the function pointer first (with [TT](TT.md) / [TTA](TTA.md)) — otherwise Non-secure code can hand Secure code a pointer into Secure memory, and although the SAU will catch it, you have wasted cycles on what should have been an early reject.

### Example 2 — Validate an NS callback with TTA before invoking it

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Illustrative — full use requires a CMSE-enabled toolchain build.
    @ BLXNS demo 2: vet a Non-secure callback pointer, then call it.
    @ r0 = candidate callback (handed to us across the boundary).
    bic     r1, r0, #1          @ probe address with the T-bit cleared
    tta     r2, r1              @ Non-secure-view attribution
    lsrs    r3, r2, #22
    ands    r3, r3, #1          @ bit 22: address is Non-secure
    beq     .Lbad
    lsrs    r3, r2, #21
    ands    r3, r3, #1          @ bit 21: NSC (must be 0 for a plain NS callback)
    bne     .Lbad
    bic     r0, r0, #1          @ ensure bit[0]=0 -> BLXNS transitions to NS
    blxns   r0                  @ call NS callback; resume in Secure here
    b       loop
.Lbad:
    movs    r0, #0
loop:
    b       loop
```

**Walkthrough:** Before letting the Non-secure side influence Secure control flow, we use `TTA` (the alternate-domain query) to look up *the Non-secure view* of the candidate address. We require the NS bit set and the NSC bit clear — i.e. the pointer must aim at plain Non-secure code, not at one of our own NSC veneers (which an attacker could otherwise abuse to ricochet back into a half-entered secure routine). Only then do we `BLXNS`. The hardware pushes the Secure return frame, scrubs caller-saved registers so we don't leak Secure data into the callback's `r0`–`r3`, and switches to Non-secure state. When the callback eventually executes `BX LR`, the magic `FNC_RETURN` value pops our Secure frame and resumes here.

## See also

- [BXNS](BXNS.md) — non-link variant; used for returning to Non-secure
- [SG](SG.md) — the gate Non-secure uses to come *into* Secure
- [TT](TT.md) / [TTA](TTA.md) / [TTAT](TTAT.md) — validate pointers crossing the boundary

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.15 — *BLXNS*.
