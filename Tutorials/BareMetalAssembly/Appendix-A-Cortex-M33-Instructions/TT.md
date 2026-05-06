# TT — Test Target: query SAU/IDAU attributes of an address

TrustZone for Armv8-M splits the chip into **Secure** and **Non-secure** worlds, with the **SAU** (Security Attribution Unit) and the device's **IDAU** deciding which addresses belong to which world. When code receives a pointer from across the boundary it must not blindly dereference it. `TT` asks the hardware: *"if I touched this address, what would happen?"* — and you get back the security and MPU region info as a bitfield, with no actual memory access.

## Class & availability

- **Class:** Security (System query)
- **Architecture:** ARMv8-M + Security (the instruction *encoding* is always present, but several result bits are RES0 unless the Security extension is implemented)
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None (but unprivileged callers see fewer result bits)
- **Secure-state required:** No — `TT` queries the **current** security state.

## Synopsis

```text
TT  <Rd>, <Rn>
```

Look up the address in `Rn`; write the attribution result to `Rd`.

**When you'd actually use this:** `TT` is the *bouncer* that lets Secure code peek at a pointer's SAU/IDAU/MPU attribution **without dereferencing it**. The canonical Arduino Nano Matter case: the Silicon Labs Secure Library receives a buffer pointer from the Non-secure Matter stack ("please fill this with a freshly-signed attestation blob") and must confirm the buffer is genuinely Non-secure memory — otherwise a malicious NS caller could trick Secure code into writing secrets *into* Secure memory it can later read back, the textbook *confused-deputy* attack. Without `TT`, Secure code would have no race-free way to validate NS pointer arguments, and every secure-callable would be a confused-deputy waiting to happen. The instruction does no load and cannot fault on the probed address, which is exactly why it can sit in front of every dereference.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register (result word) | R0–R12, R14. PC/SP UNPREDICTABLE. |
| `<Rn>` | register holding address to probe | R0–R12, R14. PC/SP UNPREDICTABLE. |

## Operation (pseudocode)

```text
addr   = Rn
mpu    = MPU_LookUp(addr, CurrentSecurityState(), CurrentPrivilege())
sau    = SAU_LookUp(addr)
idau   = IDAU_LookUp(addr)
result = 0
result[7:0]   = mpu.region            @ MREGION
result[8]     = mpu.region_valid      @ MRVALID
result[15:8]  = sau.region            @ SREGION (Secure callers only)
result[16]    = sau.region_valid      @ SRVALID (Secure callers only)
result[21]    = (sau.attr == NSC)     @ NSC
result[22]    = (sau.attr != Secure)  @ "address is Non-secure"
result[23]    = secure_callable_readable_from_NS()  @ S
                                       @ (= readable from current state)
Rd = result
```

(Bits not listed read as zero. Exact field map is in DDI 0553B §D1.2.249.)

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates APSR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 32-bit | `1110 1000 0100 Rn 1111 Rd 0000 0000` (the `T`/`A` bits in the immediate field select TT vs TTT vs TTA vs TTAT) |

## Exceptions / faults

- `(none)` — `TT` performs no memory access; it cannot fault on the probed address. It is fully synchronous and does not raise SecureFault even if the probed address is "wrong" — that's the whole point.

## Example

### Example 1 — Probing the NS bit on a received pointer

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    @ Illustrative — full use requires a CMSE-enabled toolchain build.

    .text
    .global  validate_pointer
    .thumb_func
validate_pointer:
    @ r0 = pointer to validate (received from across the boundary).
    @ Returns r0 = 1 if accessible from current state, 0 otherwise.
    tt      r1, r0              @ probe attributes of *r0*
    lsrs    r2, r1, #22         @ r2[0] = "address is Non-secure"
    ands    r2, r2, #1
    @ For a Secure callee receiving a NS pointer, we want NS = 1.
    movs    r0, r2
    bx      lr
loop:
    b       loop
```

**Walkthrough:**

1. `tt r1, r0` — asks the SAU/IDAU and MPU about `r0` *as if accessed from the current security state and privilege*. No load is performed; `r1` gets the attribution word.
2. `lsrs r2, r1, #22` then `ands r2, r2, #1` — extract the "address is Non-secure" bit (bit 22). Real CMSE veneers also check bits for read/write permission and that the *whole range* (not just the first byte) lies in the right region — see GCC's `__builtin_arm_cmse_check_address_range`.
3. The result in `r0` is what a Secure callee uses to decide whether to trust the Non-secure-supplied pointer before dereferencing it.

This is the part that bites people: `TT` only inspects the **first byte** of the address. To validate a buffer you must probe the start *and* the last byte and confirm both fall in the same SAU region — otherwise an attacker can hand you a pointer that straddles a Secure boundary.

### Example 2 — Pre-flight TT before a load

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ Illustrative — full use requires a CMSE-enabled toolchain build.
    @ TT demo 2: only dereference the pointer if the current state can read it.
    @ r0 = address to read; we want r0 = *r0 on success, 0 on rejection.
    tt      r1, r0              @ probe attribution of *r0
    lsrs    r2, r1, #23
    ands    r2, r2, #1          @ bit 23: readable from current security state
    beq     .Lskip
    ldr     r0, [r0]            @ safe to dereference
    b       loop
.Lskip:
    movs    r0, #0
loop:
    b       loop
```

**Walkthrough:** `tt r1, r0` asks the SAU/IDAU/MPU what would happen if the *current* state (and current privilege) tried to access `*r0`. We extract the "readable in current state" bit and only proceed with the actual `ldr` if it is set; otherwise we return zero. Because `TT` performs no memory access, the probe itself cannot fault — making it the safe way to ask "is this address mine to read?" before the load that might otherwise raise a MemManage or SecureFault.

## See also

- [TTT](TTT.md) — same query, but unprivileged-view variant (T-flag set)
- [TTA](TTA.md) — query the *other* security state (Secure code probing Non-secure attributes)
- [TTAT](TTAT.md) — alternate domain + T-flag
- [SG](SG.md) — the entry gate that triggers the need for these checks

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.351 — *TT, TTT, TTA, TTAT*.
