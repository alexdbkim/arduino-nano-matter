# Agent instructions — Cortex-M33 instruction appendix

You are one of 14 fleet agents creating instruction reference docs for the Arduino Nano Matter (EFR32MG24, Cortex-M33).

## Your job

Create one Markdown file per mnemonic listed in your task prompt, in the folder:

```
/Users/ak/Nano/Tutorials/BareMetalAssembly/Appendix-A-Cortex-M33-Instructions/
```

File name = **uppercase mnemonic** + `.md`. Examples: `MOV.md`, `SADD8.md`, `VLDR.md`, `MRS.md`, `SG.md`.

## File template (use EXACTLY this structure, in this order, with these exact headings)

````markdown
# MNEMONIC — one-line plain-English summary

## Class & availability

- **Class:** Data movement | Arithmetic | Logical | Shift/Rotate | Compare | Branch | Bit manipulation | Saturation | Multiply | DSP-SIMD | Floating-point | System | Hint | Security
- **Architecture:** ARMv8-M Mainline (base) | + DSP | + FP | + Security
- **Available on Arduino Nano Matter (EFR32MG24, Cortex-M33):** ✅
- **Privilege required:** None | Privileged only
- **Secure-state required:** No | Yes (Security extension)

## Synopsis

```text
MNEMONIC{S}{<cond>} {<Rd>,} <Rn>, <operand2>
```

A 2–5 sentence "**When you'd actually use this**" paragraph follows the syntax block. It must name concrete real-world Cortex-M33 firmware contexts in which the instruction appears (DSP inner loop, MMIO read, RTOS context switch, atomic retry, saturating mix, TrustZone gateway, etc.) and briefly say what alternative would be worse. No generic platitudes — every paragraph is mnemonic-specific.

## Operands

| Field | Type | Constraints |
|-------|------|-------------|
| `<Rd>` | destination register | … |
| `<Rn>` | source register | … |

## Operation (pseudocode)

```text
if ConditionPassed() then
    <instruction-specific behaviour>
    if S == '1' then APSR.{N,Z,C,V} = …
```

## Flags affected

| N | Z | C | V | Q |
|---|---|---|---|---|
| ✓/– | ✓/– | ✓/– | ✓/– | ✓/– |

One-sentence note on when flags update (e.g. only with `S` suffix, always, never).

## Encodings

| Variant | Width | Form |
|---------|-------|------|
| T1 | 16-bit | … |
| T2 | 32-bit | … |

## Exceptions / faults

- UsageFault on unaligned access if `CCR.UNALIGN_TRP = 1` (etc.) — or `(none)`.

## Example

Two labelled examples, each a self-contained compilable unit.

### Example 1 — <basic shape>

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ MNEMONIC demo: <one-line description>
    <4–10 lines of real work>
loop:
    b   loop
```

**Walkthrough:**

1. `<first instruction>` — what it does, what it leaves in which register / flag.
2. `<second instruction>` — …

### Example 2 — <idiomatic / real-world pattern>

```asm
    .syntax unified
    .cpu    cortex-m33
    .thumb
    .global  reset_handler
    .thumb_func
reset_handler:
    @ MNEMONIC demo 2: <a different idiomatic pattern>
    <4–10 lines showing the instruction inside a realistic mini-pattern>
loop:
    b   loop
```

**Walkthrough:**

1. …
2. …

## See also

- [RELATED1](RELATED1.md) — relationship in one phrase
- [RELATED2](RELATED2.md)

## Reference

- *Arm®v8-M Architecture Reference Manual* (DDI 0553B), §C2.4.x — *Instruction name in ARM ARM*.
````

## Hard rules — every file must obey

1. **No placeholders.** Fill every field with real, accurate content from the Armv8-M ARM (DDI 0553B). No `TBD`, no "see ARM ARM" handwaves.
2. **Examples must compile** under `arm-none-eabi-as -mcpu=cortex-m33 -mthumb`. They start with `.syntax unified` / `.cpu cortex-m33` / `.thumb` and end with `loop: b loop`. For complex examples, run the assembler to check (use `bash` tool in /tmp).
3. **FPU examples:** add `@ Prerequisite: CPACR.CP10/CP11 = 0b11 (FPU enabled)` as a comment line after `.thumb_func`. The example itself does not need to enable the FPU.
4. **TrustZone examples:** mark as `@ Illustrative — full use requires a CMSE-enabled toolchain build.`
5. **Walkthrough**: explain each instruction's *effect*, not what its mnemonic literally spells.
6. **Flags table:** use `✓` for affected, `–` for unaffected. `Q` is only relevant for saturating instructions.
7. **Encodings:** distinguish T1 (16-bit) from T2/T3/T4 (32-bit). Many DSP and FPU instructions are 32-bit only — say so.
8. **"See also" links** must reference real sibling files using the canonical uppercase-mnemonic naming. If you reference a mnemonic from another category (you don't know if it's been written yet), link it anyway — it will exist by the time the PR lands.
9. **Length:** aim for 90–180 lines per file (was 50–120 before the synopsis-prose + second-example update). Terse, complete, no fluff.
9a. **Synopsis prose paragraph:** 2–5 sentences, concrete to the mnemonic, names real firmware contexts and explains why an alternative would be worse. Generic prose is rejected.
9b. **Two examples:** every file has `### Example 1 — <label>` and `### Example 2 — <label>`. Each compiles standalone with the full `reset_handler` / `loop: b loop` scaffold. Each has its own `**Walkthrough:**`. The two examples must illustrate *different* uses (basic shape vs idiomatic pattern), not minor variants of the same code.
10. **Do NOT** `git add`, `git commit`, or `git push`. Only create files. The orchestrator will commit at the end.

## Tone

Like the existing tutorials in `Tutorials/BareMetalAssembly/04-first-program/README.md`: matter-of-fact, ELI5 friendly but technically precise, occasional "this is the part that bites people" callouts.

## Output

When done, reply with:
- count of files created
- list of file names
- any mnemonics you couldn't write (and why)
