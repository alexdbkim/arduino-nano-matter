# TTAT — Test Target Alternate domain with T-flag (unprivileged NS view)

TrustZone for Armv8-M splits the chip into **Secure** and **Non-secure** worlds. `TTAT` combines [TTA](TTA.md) (alternate domain — Secure code probing the Non-secure side) with the **T-flag** from [TTT](TTT.md) (force unprivileged view). The result tells privileged Secure code: *"would unprivileged Non-secure code be allowed to touch this address?"* — which is exactly the question CMSE has to answer for pointers handed in by an unprivileged Non-secure thread.

## Class & availability

- **Class:** Security (System query)
- **Architecture:** ARMv8-M + Security
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None to execute; only meaningful when called from Secure code that needs to vet a Non-secure pointer.
- **Secure-state required:** **Yes** — UNDEFINED in Non-secure state.

## Synopsis

```text
TTAT  <Rd>, <Rn>
```

Same shape as `TT`. Both **A** and **T** bits are set in the encoding.

**When you'd actually use this:** `TTAT` is the workhorse of CMSE pointer validation: alternate domain (Non-secure MPU) **plus** unprivileged view, i.e. the strictest answer to *"could the actual Non-secure unprivileged thread that called us touch this?"*. Every Silicon Labs Secure-Library entry point on the Arduino Nano Matter that accepts a buffer from a Non-secure unprivileged caller — which is most of them, since the Matter and Bluetooth stacks normally run unprivileged — relies on `TTAT` (via GCC's `__builtin_arm_cmse_check_address_range`). If you used `TTA` instead, your validator would over-approve memory only privileged NS code could reach; if you used `TT`, you'd over-approve memory only Secure code can reach. `TTAT` is the only probe that gives you a confused-deputy-proof yes/no for the common case.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register (result word) | R0–R12, R14. PC/SP UNPREDICTABLE. |
| `<Rn>` | register holding address to probe | R0–R12, R14. PC/SP UNPREDICTABLE. |

## Operation (pseudocode)

```text
if CurrentSecurityState() != Secure then UNDEFINED;
addr  = Rn
sec   = NonSecure                 @ A-flag: alternate domain
priv  = Unprivileged              @ T-flag: force unprivileged
mpu   = MPU_LookUp(addr, sec, priv)   @ uses NS MPU, unpriv permissions
sau, idau = same as TT
Rd    = AttributionWord(mpu, sau, idau)
                                  @ bits 30 (T) and 31 (A) both set in result
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates APSR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1110 1000 0100 Rn 1111 Rd 1100 0000` (TT-family with T=1, A=1) |

## Exceptions / faults

- **UNDEFINED** in Non-secure state → UsageFault (UNDEFINSTR).
- Otherwise `(none)` — no memory access.

## Example

### Example 1 — Range check for an unprivileged NS buffer

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    @ Illustrative — full use requires a CMSE-enabled toolchain build.
    @ Mirrors GCC's __builtin_arm_cmse_check_address_range(p, n,
    @   CMSE_NONSECURE | CMSE_MPU_UNPRIV | CMSE_MPU_READWRITE).

    .text
    .global  secure_validate_ns_buf
    .thumb_func
secure_validate_ns_buf:
    @ r0 = base, r1 = length (>0).
    @ Returns r0 = base if [base, base+len) is fully NS, RW, and visible
    @ to unprivileged NS code; else r0 = 0.
    cbz     r1, .Lbad
    adds    r2, r0, r1
    subs    r2, r2, #1          @ r2 = last byte address
    ttat    r3, r0              @ probe first byte (NS, unpriv)
    ttat    r12, r2             @ probe last byte  (NS, unpriv)

    @ Both probes must agree on SAU+MPU region:
    eors    r3, r3, r12
    lsrs    r3, r3, #8          @ ignore the MPU-region byte? No — we
                                @ keep both bytes equal: full word == 0
                                @ after EOR means same MREGION+SREGION.
    cbnz    r3, .Lbad

    @ Require: NS bit set, NSC bit clear, readable bit set.
    movs    r2, #1
    lsls    r3, r2, #22         @ NS
    tst     r12, r3
    beq     .Lbad
    lsls    r3, r2, #21         @ NSC
    tst     r12, r3
    bne     .Lbad
    bx      lr                  @ r0 = original base, accepted
.Lbad:
    movs    r0, #0
    bx      lr
loop:
    b       loop
```

**Walkthrough:**

1. `cbz r1, .Lbad` — zero-length buffers are rejected; otherwise the "last byte" math underflows.
2. `ttat r3, r0` and `ttat r12, r2` — probe the first and last bytes of the buffer with the **Non-secure unprivileged** view. No memory is read; only the SAU/IDAU and Non-secure MPU are consulted.
3. The `EORS` / `CBNZ` pair confirms both endpoints are in the *same* SAU and Non-secure MPU region. If they differ, the buffer crosses a region boundary — reject. (This is the canonical fix for the "TT only checks one byte" bite.)
4. The two `TST`s require that the address attribution is plain Non-secure (NS bit set, NSC bit clear). NSC pointers are valid for `BLXNS` targets but must never be accepted as data buffers.
5. On success, the original `r0` flows through to the caller.

This is the part that bites people: applying the T-flag matters even when *you* are privileged Secure code. Without it, your validator says "yes" for memory the Non-secure caller could not actually access — your subsequent helpful copy then succeeds where the caller's own dereference would have faulted, and you have just become a confused-deputy oracle.

### Example 2 — Single-byte TTAT before a Secure-side store into NS memory

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Illustrative — full use requires a CMSE-enabled toolchain build.
    @ TTAT demo 2: one-byte write into an NS-supplied location.
    @ r0 = NS byte address; r1 = byte value to store.
    ttat    r2, r0              @ NS unprivileged-view attribution
    lsrs    r3, r2, #22
    ands    r3, r3, #1          @ bit 22: NS
    beq     .Lbad
    lsrs    r3, r2, #21
    ands    r3, r3, #1          @ bit 21: NSC must be 0
    bne     .Lbad
    strb    r1, [r0]            @ Secure-side store into NS memory: now safe
    movs    r0, #0
    b       loop
.Lbad:
    movs    r0, #1
loop:
    b       loop
```

**Walkthrough:** The Secure-Library entry point wants to deposit a single status byte into a Non-secure caller's variable. We `ttat` the address — the result reflects the *Non-secure unprivileged* MPU view, exactly matching the threat model of an unprivileged Matter task. Demanding "NS = 1, NSC = 0" rejects pointers into Secure memory and into our own veneer tables. Only then do we issue `strb`; if `TTAT` had said no, the eventual store would have raised SecureFault anyway, but performing the explicit check first turns a hardware fault into a clean, reportable error code.

## See also

- [TT](TT.md) / [TTT](TTT.md) — same-domain probes (current state)
- [TTA](TTA.md) — alternate domain, privileged view
- [SG](SG.md) / [BXNS](BXNS.md) / [BLXNS](BLXNS.md) — the boundary-crossing gates

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.351 — *TT, TTT, TTA, TTAT*.
- *ARM®v8-M Security Extensions: Requirements on Development Tools* — CMSE intrinsics map.
