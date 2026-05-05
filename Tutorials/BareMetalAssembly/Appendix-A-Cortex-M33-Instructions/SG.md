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

## See also

- [BXNS](BXNS.md) — return from Secure to Non-secure
- [BLXNS](BLXNS.md) — Secure code calling out to Non-secure
- [TT](TT.md) — query SAU/IDAU attributes of an address
- [TTA](TTA.md) — same, but probe the alternate (Non-secure) domain

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.290 — *SG*.
- *Armv8-M Security Extensions: Requirements on Development Tools* (ARM ECM0359818).
