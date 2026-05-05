# BXNS — Branch and eXchange to Non-Secure

TrustZone for Armv8-M splits the chip into **Secure** and **Non-secure** worlds. When Secure code wants to *return* to (or jump into) Non-secure code, it cannot use a plain `BX` — that would leak a Secure-domain return into Non-secure memory. `BXNS` is the dedicated branch that crosses the boundary safely: the CPU drops into Non-secure state as part of the branch.

## Class & availability

- **Class:** Security (Branch)
- **Architecture:** ARMv8-M + Security
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None
- **Secure-state required:** Yes — `BXNS` is UNDEFINED if executed in Non-secure state.

## Synopsis

```text
BXNS  <Rm>
```

The branch target is `Rm`. Bit[0] of `Rm` selects the destination security state: **0 = Non-secure**, 1 = Secure (i.e. a normal `BX` semantics, no state change). For the typical "return to Non-secure" case, bit[0] must be **0**.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rm>` | source register holding target address | Any of R0–R14. R15 (PC) is UNPREDICTABLE. |

Note: unlike Thumb's usual rule, bit[0] of `Rm` is **not** the T-bit here — it is the security indicator. Thumb state is implicit; Armv8-M is Thumb-only.

## Operation (pseudocode)

```text
if CurrentSecurityState() != Secure then UNDEFINED;
target  = Rm AND 0xFFFFFFFE
to_NS   = (Rm[0] == '0')
if to_NS then
    PushFNCReturnContext()      @ scrub Secure callee-saved regs as required
    SwitchToNonSecureState()
PC = target
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| – | – | – | – | – |

Never updates APSR.

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | `0100 0111 0 Rm 100`  (similar shape to `BX`, distinguished by the trailing `100`) |

## Exceptions / faults

- **UNDEFINED** if executed in Non-secure state → UsageFault (INVSTATE / UNDEFINSTR).
- **SecureFault (INVTRAN)** if the target address claims to be Non-secure (bit[0]=0) but actually points into Secure memory per the SAU/IDAU.
- No alignment faults — the address is forced even.

## Example

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    @ Illustrative — full use requires a CMSE-enabled toolchain build.
    @ Build flags: -mcmse, with NSC veneers in .gnu.sgstubs.

    .text
    .global  secure_entry
    .thumb_func
secure_entry:
    sg                          @ legal Non-secure -> Secure gate
    @ ... do Secure work, result in r0 ...
    movs    r0, #42
    bic     lr, lr, #1          @ ensure LR bit[0] = 0 (Non-secure return)
    bxns    lr                  @ return to Non-secure caller
loop:
    b       loop
```

**Walkthrough:**

1. `sg` — opens the gate (see [SG](SG.md)); we are now executing in Secure state with `LR` holding a tagged Non-secure return address (`FNC_RETURN`).
2. `movs r0, #42` — produce the Secure-side result in the ABI return register.
3. `bic lr, lr, #1` — make sure bit[0] of `LR` is 0 so `BXNS` will switch to Non-secure. (The compiler/veneer normally guarantees this; the `BIC` here is defensive.)
4. `bxns lr` — branches to `LR`, scrubs caller-saved Secure registers per the calling convention, and drops the core into Non-secure state. The Non-secure caller resumes as if a normal function returned.

This is the part that bites people: if you accidentally use plain `BX LR` here, you stay in Secure state and start executing Non-secure-addressed code with Secure privileges — the SAU then raises a SecureFault. Always `BXNS` on the way out.

## See also

- [SG](SG.md) — the matching entry gate
- [BLXNS](BLXNS.md) — Secure code *calling* Non-secure (not returning)
- [TT](TT.md) / [TTA](TTA.md) — validate pointers received across the boundary

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.18 — *BXNS*.
