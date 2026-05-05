# TTA — Test Target Alternate domain (Secure probing Non-secure)

TrustZone for Armv8-M splits the chip into **Secure** and **Non-secure** worlds. `TTA` is the *alternate-domain* form of [TT](TT.md): when **Secure code** wants to know what the **Non-secure** view of an address looks like — would Non-secure code be allowed to touch it, and which Non-secure MPU region governs it — it uses `TTA`. This is the workhorse for validating pointers received from Non-secure callers without trusting the caller's word for it.

## Class & availability

- **Class:** Security (System query)
- **Architecture:** ARMv8-M + Security
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None to execute. The result reflects Secure-state privilege when checking MPU permissions (see [TTAT](TTAT.md) for the unprivileged variant).
- **Secure-state required:** **Yes** — `TTA` is UNDEFINED if executed from Non-secure (Non-secure code is not allowed to peek into Secure attribution).

## Synopsis

```text
TTA  <Rd>, <Rn>
```

Same shape as `TT`; the **A** bit in the encoding asks the hardware to use the *other* security domain (which, since `TTA` only runs from Secure, means Non-secure) for the lookup.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register (result word) | R0–R12, R14. PC/SP UNPREDICTABLE. |
| `<Rn>` | register holding address to probe | R0–R12, R14. PC/SP UNPREDICTABLE. |

## Operation (pseudocode)

```text
if CurrentSecurityState() != Secure then UNDEFINED;
addr     = Rn
sec      = NonSecure              @ <-- alternate domain
priv     = CurrentPrivilege()     @ Secure code's own privilege
mpu      = MPU_LookUp(addr, sec, priv)   @ uses the NS MPU
sau/idau = same as TT
Rd       = AttributionWord(mpu, sau, idau)
                                  @ result bit 31 ("A") set so readers
                                  @ know this was an alternate-domain probe
```

The MPU lookup is performed against the **Non-secure MPU**, not the Secure one. SAU and IDAU answers are global and unchanged.

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates APSR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1110 1000 0100 Rn 1111 Rd 1000 0000` (TT-family with T=0, A=1) |

## Exceptions / faults

- **UNDEFINED** in Non-secure state → UsageFault (UNDEFINSTR).
- Otherwise `(none)` — no memory access is performed.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    @ Illustrative — full use requires a CMSE-enabled toolchain build.
    @ Equivalent to GCC's __builtin_arm_cmse_check_pointed_object(p, 6).

    .text
    .global  cmse_check_ns_rw
    .thumb_func
cmse_check_ns_rw:
    @ r0 = NS pointer to validate (read+write).
    @ Returns r0 = the pointer if it is a valid NS RW location, else 0.
    tta     r1, r0              @ probe NS view of *r0* from Secure
    @ Required result bits (DDI 0553B):
    @   bit 22 = "address is Non-secure"          must be 1
    @   bit 23 = "readable in current state"      must be 1
    @   bit 31 = "A" (set, confirms alt-domain)
    @   bit 21 = NSC                              must be 0 for plain NS
    movs    r2, #1
    lsls    r3, r2, #22         @ NS bit
    tst     r1, r3
    beq     .Lreject
    lsls    r3, r2, #23         @ readable
    tst     r1, r3
    beq     .Lreject
    bx      lr                  @ r0 unchanged: pointer trusted
.Lreject:
    movs    r0, #0
    bx      lr
loop:
    b       loop
```

**Walkthrough:**

1. `tta r1, r0` — Secure code asks: "from a Non-secure access perspective, what are the SAU and (NS) MPU attributes of `*r0`?" No load is performed.
2. `lsls r3, r2, #22` / `tst r1, r3` — check that bit 22 ("address is Non-secure") is set. If the caller handed us a pointer into Secure or NSC memory, this fails — and we *must* reject it, otherwise the eventual access raises SecureFault.
3. `lsls r3, r2, #23` / `tst r1, r3` — check that the location is readable from the relevant state. The matching CMSE builtin also checks writability when asked.
4. On success, `r0` flows through unchanged; on failure, return NULL.

This is the part that bites people: a Non-secure caller that hands Secure code a pointer to its own NSC veneer table can pass a naive `TT` check (it's "accessible") yet still let the attacker observe Secure metadata. Use `TTA` and explicitly require bit 22 = 1 and bit 21 = 0 — i.e. plain Non-secure, not NSC.

## See also

- [TT](TT.md) — same query against the *current* domain
- [TTT](TTT.md) — current domain, unprivileged view
- [TTAT](TTAT.md) — alternate domain + unprivileged view (the most common CMSE check)
- [SG](SG.md) / [BLXNS](BLXNS.md) — the gates whose pointers you are vetting

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.351 — *TT, TTT, TTA, TTAT*.
