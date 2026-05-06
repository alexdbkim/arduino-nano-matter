# SG — Secure Gateway: legal entry from Non-secure into Secure code

TrustZone for Armv8-M splits the chip into two worlds, **Secure** and **Non-secure**. Non-secure code is not allowed to just `BL` into Secure code — it would be a privilege escalation. Instead, every Secure entry point must begin with an `SG` instruction placed in a special **Non-Secure Callable (NSC)** region. `SG` is the *only* instruction the hardware accepts as a legal door from Non-secure into Secure.

## Class & availability

- **Class:** Security
- **Architecture:** ARMv8-M + Security
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** Executed *from* Non-secure (in an NSC region); transitions CPU to Secure state.

## Synopsis

```text
SG
```

**When you'd actually use this:** `SG` is the *doorway* every secure-callable veneer starts with. On the Arduino Nano Matter the EFR32MG24's Silicon Labs **Secure Library** (key vault, attestation signing for Matter, secure-boot helpers) runs in Secure state and exposes its API only through NSC veneers — every one of those veneers begins with `SG`. Without that mandate, a Non-secure attacker could `BL` a few bytes past the official entry point and skip the privilege / argument-validation prologue; the architecture forbids it by raising **SecureFault (INVEP)** on any branch from NS into Secure that does not land on an `SG`. Think of it as the bouncer-checked door: you can only enter the club through *this* door, and only at this exact spot.

No operands. Always 32-bit, always unconditional.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| (none) | — | `SG` takes no operands. |

## Operation (pseudocode)

```text
if CurrentSecurityState() == NonSecure then
    if AddressIsInNSCRegion(PC) then
        SwitchToSecureState()
        if LR.bit[0] == 0 then          @ caller was Non-secure
            LR = LR with bit[0] cleared @ FNC_RETURN tag preserved
        @ continue execution at PC+4 in Secure state
    else
        SecureFault(INVEP)              @ illegal entry
else
    NOP                                 @ already Secure: harmless
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

`SG` never updates APSR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1110 1001 0111 1111 1110 1001 0111 1111` (the encoding is intentionally a NOP-shaped pair so an SG located in non-NSC memory degrades to NOP) |

## Exceptions / faults

- **SecureFault (INVEP)** if `SG` executes outside an NSC region while the core is Non-secure.
- **SecureFault (INVTRAN)** if a Non-secure caller branches into Secure memory at any address other than an `SG`.
- No UsageFault, no MemManage.

## Example

### Example 1 — NSC veneer for a secure-callable add

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    @ Illustrative — full use requires a CMSE-enabled toolchain build.
    @ With GCC: -mcmse, and the veneer lives in section ".gnu.sgstubs"
    @ which the linker places in the NSC region declared by the SAU.

    .section .gnu.sgstubs,"ax",%progbits
    .global  secure_add_entry
    .thumb_func
secure_add_entry:
    @ NSC veneer: first instruction MUST be SG.
    sg
    b       secure_add_impl     @ tail-call into the real Secure function

    .text
    .thumb_func
secure_add_impl:
    adds    r0, r0, r1          @ r0 = a + b   (Secure-side work)
    bxns    lr                  @ return to Non-secure caller
loop:
    b       loop
```

**Walkthrough:**

1. `sg` — checks the PC is inside an NSC region; if so, switches the core into Secure state and falls through. If a Non-secure caller landed *anywhere else* in Secure memory, the core would raise SecureFault instead.
2. `b secure_add_impl` — ordinary branch, now executing in Secure state, into the real implementation in regular `.text` (Secure-only) memory.
3. `bxns lr` — returns to the Non-secure caller, switching state back. See [BXNS](BXNS.md).

The NSC region itself is configured by the **SAU** (Secure Attribution Unit) or IDAU at boot. Only addresses tagged NSC are valid `SG` sites.

### Example 2 — SG followed by a Non-secure caller-privilege check

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Illustrative — full use requires a CMSE-enabled toolchain build.
    @ SG demo 2: secure-callable that refuses unprivileged Non-secure callers.
    sg                          @ legal NS->S entry (must be in an NSC region)
    mrs     r2, control_ns      @ read the Non-secure CONTROL register
    tst     r2, #1              @ bit 0 = nPRIV_NS: 1 if NS caller is unprivileged
    bne     .Lreject
    movs    r0, #0              @ success status -> NS
    bxns    lr                  @ return to NS caller
.Lreject:
    movs    r0, #1              @ non-zero error code
    bxns    lr
loop:
    b       loop
```

**Walkthrough:** `sg` is the only legal landing pad for a Non-secure `BL` into this NSC region; the hardware switches the core to Secure state right here. `mrs r2, control_ns` reads the *Non-secure* `CONTROL` register from Secure state — that's how Secure code learns whether its NS caller is privileged. We refuse unprivileged callers with a non-zero status, otherwise return success. The whole function ends with `bxns lr` to drop back into Non-secure state. Without the leading `SG`, a Non-secure attacker could simply `BL` to the address of `mrs` and skip the gate altogether — except they can't, because the SAU would raise SecureFault.

## See also

- [BXNS](BXNS.md) — return from Secure to Non-secure
- [BLXNS](BLXNS.md) — Secure code calling out to Non-secure
- [TT](TT.md) — query SAU/IDAU attributes of an address
- [TTA](TTA.md) — same, but probe the alternate (Non-secure) domain

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.290 — *SG*.
- *Armv8-M Security Extensions: Requirements on Development Tools* (ARM ECM0359818).
