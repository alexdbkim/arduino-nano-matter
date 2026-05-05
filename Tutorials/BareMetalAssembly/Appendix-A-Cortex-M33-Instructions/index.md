# Appendix A — Cortex-M33 Instruction Reference

Comprehensive Markdown reference for every instruction available on the Arduino Nano Matter (Silicon Labs EFR32MG24, ARM Cortex-M33 with FPv5-SP single-precision FPU, DSP, and TrustZone).

**Total: 250 instructions across 14 categories.**

Each file follows the same structure: synopsis · operands · pseudocode · flags affected · encodings · exceptions · compilable example with walkthrough · cross-links · ARM ARM section reference. See [`_template.md`](_template.md) for the template and [`_AGENT_INSTRUCTIONS.md`](_AGENT_INSTRUCTIONS.md) for the authoring rules used to generate these.

## Conventions

- File name = canonical UAL mnemonic in **uppercase** (e.g. `LDR.md`, `SADD8.md`, `VLDR.md`, `MRS.md`).
- For mnemonics with optional `S` (flag-setting) suffix on the same encoding family — e.g. `ADD`/`ADDS`, `SUB`/`SUBS`, `AND`/`ANDS` — both forms are documented in the **un-suffixed** file. `MOVS` is the lone exception (separate file) because of its special role in setting flags from immediate moves.
- Examples assume the integer toolchain `arm-none-eabi-as -mcpu=cortex-m33 -mthumb`. FPU examples additionally need `-mfpu=fpv5-sp-d16 -mfloat-abi=hard` and include a `.fpu fpv5-sp-d16` directive.
- FPU examples assume the FPU is enabled at runtime (`CPACR.CP10 = CP11 = 0b11`). Each FPU file calls this out.
- TrustZone examples are illustrative — full use requires CMSE-enabled compilation and SAU configuration.

## By category

### Data movement & memory access

*Loads, stores, register moves, multi-register transfers, exclusive monitors, acquire/release ordering.*  ·  **44 instructions**

| Mnemonic | Summary |
|----------|---------|
| [`CLREX`](CLREX.md) | clear the local exclusive monitor |
| [`LDA`](LDA.md) | load-acquire of a 32-bit word (release/acquire ordering) |
| [`LDAB`](LDAB.md) | load-acquire of a byte, zero-extended (ARMv8-M) |
| [`LDAEX`](LDAEX.md) | load-acquire-exclusive of a 32-bit word (ARMv8-M) |
| [`LDAEXB`](LDAEXB.md) | load-acquire-exclusive of a byte (ARMv8-M) |
| [`LDAEXH`](LDAEXH.md) | load-acquire-exclusive of a half-word (ARMv8-M) |
| [`LDAH`](LDAH.md) | load-acquire of a half-word, zero-extended (ARMv8-M) |
| [`LDM`](LDM.md) | load multiple consecutive words from memory into a list of registers |
| [`LDR`](LDR.md) | load a 32-bit word from memory into a register |
| [`LDRB`](LDRB.md) | load a byte from memory, zero-extended into a 32-bit register |
| [`LDRD`](LDRD.md) | load two consecutive 32-bit words into a register pair |
| [`LDREX`](LDREX.md) | exclusive load of a 32-bit word, arming the local exclusive monitor |
| [`LDREXB`](LDREXB.md) | exclusive load of a byte, arming the local exclusive monitor |
| [`LDREXH`](LDREXH.md) | exclusive load of a half-word, arming the local exclusive monitor |
| [`LDRH`](LDRH.md) | load a half-word (16 bits) from memory, zero-extended into a 32-bit register |
| [`LDRSB`](LDRSB.md) | load a signed byte from memory, sign-extended to 32 bits |
| [`LDRSH`](LDRSH.md) | load a signed half-word from memory, sign-extended to 32 bits |
| [`MOV`](MOV.md) | copy a register or small immediate into a register |
| [`MOVS`](MOVS.md) | copy a register or immediate AND update N/Z (and sometimes C) |
| [`MOVT`](MOVT.md) | write a 16-bit immediate into the top half of a register, leaving the bottom half intact |
| [`MOVW`](MOVW.md) | load an arbitrary 16-bit immediate into the bottom half of a register |
| [`MVN`](MVN.md) | move bitwise NOT of an immediate or register into a register |
| [`POP`](POP.md) | pop a list of registers from the (full-descending) stack |
| [`PUSH`](PUSH.md) | push a list of registers onto the (full-descending) stack |
| [`SMULBB`](SMULBB.md) | Signed 16×16 multiply: bottom half of `Rn` × bottom half of `Rm` → 32-bit `Rd`. |
| [`SMULBT`](SMULBT.md) | Signed 16×16 multiply: bottom half of `Rn` × top half of `Rm` → 32-bit `Rd`. |
| [`SMULTB`](SMULTB.md) | Signed 16×16 multiply: top half of `Rn` × bottom half of `Rm` → 32-bit `Rd`. |
| [`SMULTT`](SMULTT.md) | Signed 16×16 multiply: top half of `Rn` × top half of `Rm` → 32-bit `Rd`. |
| [`SMULWB`](SMULWB.md) | Signed 32-bit × 16-bit (bottom half of `Rm`) multiply; result is the top 32 bits of the 48-bit product. |
| [`SMULWT`](SMULWT.md) | Signed 32-bit × 16-bit (top half of `Rm`) multiply; result is the top 32 bits of the 48-bit product. |
| [`STL`](STL.md) | store-release of a 32-bit word (ARMv8-M) |
| [`STLB`](STLB.md) | store-release of a byte (ARMv8-M) |
| [`STLEX`](STLEX.md) | store-release-exclusive of a 32-bit word (ARMv8-M) |
| [`STLEXB`](STLEXB.md) | store-release-exclusive of a byte (ARMv8-M) |
| [`STLEXH`](STLEXH.md) | store-release-exclusive of a half-word (ARMv8-M) |
| [`STLH`](STLH.md) | store-release of a half-word (ARMv8-M) |
| [`STM`](STM.md) | store multiple registers to consecutive memory words |
| [`STR`](STR.md) | store a 32-bit word from a register to memory |
| [`STRB`](STRB.md) | store the low byte of a register to memory |
| [`STRD`](STRD.md) | store two registers as consecutive 32-bit words |
| [`STREX`](STREX.md) | conditional ("exclusive") store of a 32-bit word |
| [`STREXB`](STREXB.md) | conditional exclusive store of a byte |
| [`STREXH`](STREXH.md) | conditional exclusive store of a half-word |
| [`STRH`](STRH.md) | store the low half-word (16 bits) of a register to memory |

### Arithmetic

*Add, subtract, multiply, divide, address-form. 32-bit and 64-bit forms.*  ·  **16 instructions**

| Mnemonic | Summary |
|----------|---------|
| [`ADC`](ADC.md) | add with carry; the building block of multi-word addition |
| [`ADD`](ADD.md) | add two values, optionally updating the flags |
| [`ADR`](ADR.md) | load a PC-relative address into a register (synthetic) |
| [`MLA`](MLA.md) | multiply-accumulate: `Rd = Ra + (Rn × Rm)` |
| [`MLS`](MLS.md) | multiply-subtract: `Rd = Ra − (Rn × Rm)` |
| [`MUL`](MUL.md) | 32-bit multiply, low 32 bits of the product |
| [`NEG`](NEG.md) | two's-complement negation (alias for `RSBS Rd, Rn, #0`) |
| [`RSB`](RSB.md) | reverse subtract: `Rd = operand2 − Rn` |
| [`SBC`](SBC.md) | subtract with borrow; the building block of multi-word subtraction |
| [`SDIV`](SDIV.md) | signed 32-bit integer division |
| [`SMLAL`](SMLAL.md) | signed multiply and accumulate into a 64-bit pair |
| [`SMULL`](SMULL.md) | signed 32×32 → 64-bit multiply |
| [`SUB`](SUB.md) | subtract two values, optionally updating the flags |
| [`UDIV`](UDIV.md) | unsigned 32-bit integer division |
| [`UMLAL`](UMLAL.md) | unsigned multiply and accumulate into a 64-bit pair |
| [`UMULL`](UMULL.md) | unsigned 32×32 → 64-bit multiply |

### Logical, shift, compare

*Bitwise AND/OR/EOR/BIC/ORN, shifts and rotates, flag-setting compares.*  ·  **14 instructions**

| Mnemonic | Summary |
|----------|---------|
| [`AND`](AND.md) | bitwise AND of two values |
| [`ASR`](ASR.md) | arithmetic shift right (signed divide by powers of two) |
| [`BIC`](BIC.md) | bit clear: AND with the bitwise NOT of operand2 |
| [`CMN`](CMN.md) | compare negative: add and set flags, discard the result |
| [`CMP`](CMP.md) | compare: subtract and set flags, discard the result |
| [`EOR`](EOR.md) | bitwise exclusive-OR (XOR) of two values |
| [`LSL`](LSL.md) | logical shift left (multiply by powers of two) |
| [`LSR`](LSR.md) | logical shift right (unsigned divide by powers of two) |
| [`ORN`](ORN.md) | bitwise OR with the NOT of operand2 |
| [`ORR`](ORR.md) | bitwise inclusive OR of two values |
| [`ROR`](ROR.md) | rotate right |
| [`RRX`](RRX.md) | rotate right with extend (33-bit rotate through carry) |
| [`TEQ`](TEQ.md) | test equivalence: EOR that updates flags only |
| [`TST`](TST.md) | test bits: AND that updates flags only |

### Branch & control flow

*Unconditional and conditional branches, calls, IT blocks, table branches.*  ·  **9 instructions**

| Mnemonic | Summary |
|----------|---------|
| [`B`](B.md) | branch (optionally conditional) to a PC-relative label |
| [`BL`](BL.md) | branch with link (call a subroutine via a PC-relative label) |
| [`BLX`](BLX.md) | branch with link to address held in a register |
| [`BX`](BX.md) | branch to address held in a register (no link) |
| [`CBNZ`](CBNZ.md) | compare and branch forward if register is non-zero |
| [`CBZ`](CBZ.md) | compare and branch forward if register is zero |
| [`IT`](IT.md) | If-Then: gate up to four following instructions on a condition |
| [`TBB`](TBB.md) | table branch byte (compact forward jump table, 8-bit offsets) |
| [`TBH`](TBH.md) | table branch halfword (compact forward jump table, 16-bit offsets) |

### Bit manipulation & extension

*Bit-field insert/extract/clear, count-leading-zeros, byte-reverse, zero/sign extend.*  ·  **15 instructions**

| Mnemonic | Summary |
|----------|---------|
| [`BFC`](BFC.md) | clear a contiguous bit field in a register to zero |
| [`BFI`](BFI.md) | copy the low bits of one register into a bit field of another |
| [`CLZ`](CLZ.md) | count leading zero bits in a 32-bit register |
| [`RBIT`](RBIT.md) | reverse the bit order of a 32-bit word |
| [`REV`](REV.md) | reverse byte order of a 32-bit word (endianness swap) |
| [`REV16`](REV16.md) | reverse byte order within each halfword of a 32-bit register |
| [`REVSH`](REVSH.md) | byte-swap the low halfword and sign-extend to 32 bits |
| [`SBFX`](SBFX.md) | extract a bit field and sign-extend it to 32 bits |
| [`SXTB`](SXTB.md) | sign-extend a byte from a register to 32 bits, with optional rotation |
| [`SXTB16`](SXTB16.md) | sign-extend two bytes of a register into two halfwords  + DSP |
| [`SXTH`](SXTH.md) | sign-extend a halfword from a register to 32 bits, with optional rotation |
| [`UBFX`](UBFX.md) | extract a bit field and zero-extend it to 32 bits |
| [`UXTB`](UXTB.md) | zero-extend a byte from a register to 32 bits, with optional rotation |
| [`UXTB16`](UXTB16.md) | zero-extend two bytes of a register into two halfwords  + DSP |
| [`UXTH`](UXTH.md) | zero-extend a halfword from a register to 32 bits, with optional rotation |

### Saturation

*Saturating add/subtract, signed/unsigned saturate to N bits.*  ·  **8 instructions**

| Mnemonic | Summary |
|----------|---------|
| [`QADD`](QADD.md) | saturating signed 32-bit add |
| [`QDADD`](QDADD.md) | saturating "double then add" (Rd = sat(Rm + sat(2·Rn))) |
| [`QDSUB`](QDSUB.md) | saturating "double then subtract" (Rd = sat(Rm − sat(2·Rn))) |
| [`QSUB`](QSUB.md) | saturating signed 32-bit subtract |
| [`SSAT`](SSAT.md) | signed saturate a 32-bit value to N bits |
| [`SSAT16`](SSAT16.md) | signed saturate two packed halfwords in parallel |
| [`USAT`](USAT.md) | unsigned saturate a 32-bit value to N bits |
| [`USAT16`](USAT16.md) | unsigned saturate two packed halfwords in parallel |

### DSP SIMD add/subtract

*Packed 8-bit and 16-bit parallel add/subtract, optionally halving, saturating, exchanging.*  ·  **36 instructions**

| Mnemonic | Summary |
|----------|---------|
| [`QADD16`](QADD16.md) | signed saturating per-lane add of packed halfwords |
| [`QADD8`](QADD8.md) | signed saturating per-lane add of packed bytes |
| [`QASX`](QASX.md) | signed saturating exchange-then-add-high/sub-low on packed halfwords |
| [`QSAX`](QSAX.md) | signed saturating exchange-then-sub-high/add-low on packed halfwords |
| [`QSUB16`](QSUB16.md) | signed saturating per-lane subtract of packed halfwords |
| [`QSUB8`](QSUB8.md) | signed saturating per-lane subtract of packed bytes |
| [`SADD16`](SADD16.md) | signed wrap-around per-lane add of packed halfwords |
| [`SADD8`](SADD8.md) | signed wrap-around per-lane add of packed bytes |
| [`SASX`](SASX.md) | signed wrap-around exchange-then-add-high/sub-low on packed halfwords |
| [`SHADD16`](SHADD16.md) | signed halving per-lane add of packed halfwords |
| [`SHADD8`](SHADD8.md) | signed halving per-lane add of packed bytes |
| [`SHASX`](SHASX.md) | signed halving exchange-then-add-high/sub-low on packed halfwords |
| [`SHSAX`](SHSAX.md) | signed halving exchange-then-sub-high/add-low on packed halfwords |
| [`SHSUB16`](SHSUB16.md) | signed halving per-lane subtract of packed halfwords |
| [`SHSUB8`](SHSUB8.md) | signed halving per-lane subtract of packed bytes |
| [`SSAX`](SSAX.md) | signed wrap-around exchange-then-sub-high/add-low on packed halfwords |
| [`SSUB16`](SSUB16.md) | signed wrap-around per-lane subtract of packed halfwords |
| [`SSUB8`](SSUB8.md) | signed wrap-around per-lane subtract of packed bytes |
| [`UADD16`](UADD16.md) | unsigned wrap-around per-lane add of packed halfwords |
| [`UADD8`](UADD8.md) | unsigned wrap-around per-lane add of packed bytes |
| [`UASX`](UASX.md) | unsigned wrap-around exchange-then-add-high/sub-low on packed halfwords |
| [`UHADD16`](UHADD16.md) | unsigned halving per-lane add of packed halfwords |
| [`UHADD8`](UHADD8.md) | unsigned halving per-lane add of packed bytes |
| [`UHASX`](UHASX.md) | unsigned halving exchange-then-add-high/sub-low on packed halfwords |
| [`UHSAX`](UHSAX.md) | unsigned halving exchange-then-sub-high/add-low on packed halfwords |
| [`UHSUB16`](UHSUB16.md) | unsigned halving per-lane subtract of packed halfwords |
| [`UHSUB8`](UHSUB8.md) | unsigned halving per-lane subtract of packed bytes |
| [`UQADD16`](UQADD16.md) | unsigned saturating per-lane add of packed halfwords |
| [`UQADD8`](UQADD8.md) | unsigned saturating per-lane add of packed bytes |
| [`UQASX`](UQASX.md) | unsigned saturating exchange-then-add-high/sub-low on packed halfwords |
| [`UQSAX`](UQSAX.md) | unsigned saturating exchange-then-sub-high/add-low on packed halfwords |
| [`UQSUB16`](UQSUB16.md) | unsigned saturating per-lane subtract of packed halfwords |
| [`UQSUB8`](UQSUB8.md) | unsigned saturating per-lane subtract of packed bytes |
| [`USAX`](USAX.md) | unsigned wrap-around exchange-then-sub-high/add-low on packed halfwords |
| [`USUB16`](USUB16.md) | unsigned wrap-around per-lane subtract of packed halfwords |
| [`USUB8`](USUB8.md) | unsigned wrap-around per-lane subtract of packed bytes |

### DSP multiply

*Halfword and dual SIMD multiply-accumulate, top-half 32×32, fixed-point biased rounding.*  ·  **28 instructions**

| Mnemonic | Summary |
|----------|---------|
| [`SMLABB`](SMLABB.md) | Signed 16×16 multiply (bottom half of `Rn` × bottom half of `Rm`), accumulate into `Ra`. |
| [`SMLABT`](SMLABT.md) | Signed 16×16 multiply (bottom half of `Rn` × top half of `Rm`), accumulate into `Ra`. |
| [`SMLAD`](SMLAD.md) | Dual signed 16×16 multiply, then add the two products and accumulate into a 32-bit register. |
| [`SMLADX`](SMLADX.md) | Dual signed 16×16 multiply, then add the two products (with halves of the second operand exchanged) and accumulate into a 32-bit register. |
| [`SMLALBB`](SMLALBB.md) | Signed 16×16 multiply (bottom half of `Rn` × bottom half of `Rm`); accumulate the 32-bit product into a 64-bit `{RdHi:RdLo}` pair. |
| [`SMLALBT`](SMLALBT.md) | Signed 16×16 multiply (bottom half of `Rn` × top half of `Rm`); accumulate the 32-bit product into a 64-bit `{RdHi:RdLo}` pair. |
| [`SMLALD`](SMLALD.md) | Dual signed 16×16 multiply, then sum the two products and accumulate into a 64-bit register pair. |
| [`SMLALDX`](SMLALDX.md) | Dual signed 16×16 multiply, then sum the two products and accumulate into a 64-bit register pair (with the second operand's halves exchanged). |
| [`SMLALTB`](SMLALTB.md) | Signed 16×16 multiply (top half of `Rn` × bottom half of `Rm`); accumulate the 32-bit product into a 64-bit `{RdHi:RdLo}` pair. |
| [`SMLALTT`](SMLALTT.md) | Signed 16×16 multiply (top half of `Rn` × top half of `Rm`); accumulate the 32-bit product into a 64-bit `{RdHi:RdLo}` pair. |
| [`SMLATB`](SMLATB.md) | Signed 16×16 multiply (top half of `Rn` × bottom half of `Rm`), accumulate into `Ra`. |
| [`SMLATT`](SMLATT.md) | Signed 16×16 multiply (top half of `Rn` × top half of `Rm`), accumulate into `Ra`. |
| [`SMLAWB`](SMLAWB.md) | Signed 32-bit × 16-bit (bottom half of `Rm`) multiply, take the top 32 bits of the 48-bit product, add to `Ra`. |
| [`SMLAWT`](SMLAWT.md) | Signed 32-bit × 16-bit (top half of `Rm`) multiply, take the top 32 bits of the 48-bit product, add to `Ra`. |
| [`SMLSD`](SMLSD.md) | Dual signed 16×16 multiply, then subtract the two products and accumulate into a 32-bit register. |
| [`SMLSDX`](SMLSDX.md) | Dual signed 16×16 multiply, then subtract the two products (with halves of the second operand exchanged) and accumulate into a 32-bit register. |
| [`SMLSLD`](SMLSLD.md) | Dual signed 16×16 multiply, then difference the two products and accumulate into a 64-bit register pair. |
| [`SMLSLDX`](SMLSLDX.md) | Dual signed 16×16 multiply, then difference the two products and accumulate into a 64-bit register pair (with the second operand's halves exchanged). |
| [`SMMLA`](SMMLA.md) | Signed 32×32 multiply, add to a 32-bit value placed in the top of a 64-bit field, keep the top 32 bits. |
| [`SMMLAR`](SMMLAR.md) | Signed 32×32 multiply, add to a 32-bit value placed in the top of a 64-bit field, keep the top 32 bits (with rounding). |
| [`SMMLS`](SMMLS.md) | Signed 32×32 multiply, subtract from a 32-bit value placed in the top of a 64-bit field, keep the top 32 bits. |
| [`SMMLSR`](SMMLSR.md) | Signed 32×32 multiply, subtract from a 32-bit value placed in the top of a 64-bit field, keep the top 32 bits (with rounding). |
| [`SMMUL`](SMMUL.md) | Signed 32×32 multiply, return the top 32 bits of the 64-bit product. |
| [`SMMULR`](SMMULR.md) | Signed 32×32 multiply, return the top 32 bits of the 64-bit product (rounded — `0x80000000` is added before truncation). |
| [`SMUAD`](SMUAD.md) | Dual signed 16×16 multiply, then add the two products into a 32-bit register. |
| [`SMUADX`](SMUADX.md) | Dual signed 16×16 multiply, then add the two products (with halves of the second operand exchanged) into a 32-bit register. |
| [`SMUSD`](SMUSD.md) | Dual signed 16×16 multiply, then subtract the two products into a 32-bit register. |
| [`SMUSDX`](SMUSDX.md) | Dual signed 16×16 multiply, then subtract the two products (with halves of the second operand exchanged) into a 32-bit register. |

### DSP miscellaneous

*Sum-of-absolute-differences, halfword pack, byte/halfword extend-and-add, byte-by-byte select.*  ·  **11 instructions**

| Mnemonic | Summary |
|----------|---------|
| [`PKHBT`](PKHBT.md) | pack halfword: Bottom of Rn, Top of Rm (optionally shifted) |
| [`PKHTB`](PKHTB.md) | pack halfword: Top of Rn, Bottom of Rm (optionally ASR-shifted) |
| [`SEL`](SEL.md) | select bytes from Rn or Rm based on APSR.GE flags |
| [`SXTAB`](SXTAB.md) | sign-extend byte from Rm and add to Rn |
| [`SXTAB16`](SXTAB16.md) | extract two bytes from Rm, sign-extend each to 16 bits, add to Rn (SIMD) |
| [`SXTAH`](SXTAH.md) | sign-extend halfword from Rm and add to Rn |
| [`USAD8`](USAD8.md) | sum of absolute differences across four bytes |
| [`USADA8`](USADA8.md) | sum of absolute differences, accumulated into a third register |
| [`UXTAB`](UXTAB.md) | zero-extend byte from Rm and add to Rn |
| [`UXTAB16`](UXTAB16.md) | extract two bytes from Rm, zero-extend each to 16 bits, add to Rn (SIMD) |
| [`UXTAH`](UXTAH.md) | zero-extend halfword from Rm and add to Rn |

### FPU arithmetic (FPv5-SP, single-precision)

*Add, multiply, divide, fused MAC, abs, neg, sqrt, IEEE-754 min/max, conditional select.*  ·  **19 instructions**

| Mnemonic | Summary |
|----------|---------|
| [`VABS`](VABS.md) | floating-point absolute value (single precision) |
| [`VADD`](VADD.md) | floating-point add (single precision) |
| [`VDIV`](VDIV.md) | floating-point divide (single precision) |
| [`VFMA`](VFMA.md) | fused multiply-add (single precision, single rounding) |
| [`VFMS`](VFMS.md) | fused multiply-subtract (single precision, single rounding) |
| [`VFNMA`](VFNMA.md) | fused negated multiply-add (single precision, single rounding) |
| [`VFNMS`](VFNMS.md) | fused negated multiply-subtract (single precision, single rounding) |
| [`VMAXNM`](VMAXNM.md) | IEEE-754-2008 floating-point maximum (single precision) |
| [`VMINNM`](VMINNM.md) | IEEE-754-2008 floating-point minimum (single precision) |
| [`VMLA`](VMLA.md) | floating-point multiply-accumulate (single precision, two roundings) |
| [`VMLS`](VMLS.md) | floating-point multiply-subtract (single precision, two roundings) |
| [`VMUL`](VMUL.md) | floating-point multiply (single precision) |
| [`VNEG`](VNEG.md) | floating-point negate (single precision) |
| [`VNMLA`](VNMLA.md) | floating-point negated multiply-accumulate (single precision) |
| [`VNMLS`](VNMLS.md) | floating-point negated multiply-subtract (single precision) |
| [`VNMUL`](VNMUL.md) | floating-point negated multiply (single precision) |
| [`VSEL`](VSEL.md) | conditional floating-point select (single precision) |
| [`VSQRT`](VSQRT.md) | floating-point square root (single precision) |
| [`VSUB`](VSUB.md) | floating-point subtract (single precision) |

### FPU memory & data movement

*VMOV / VLDR / VSTR / VLDM / VSTM / VPUSH / VPOP, VMRS / VMSR for FPSCR access, VCMP.*  ·  **11 instructions**

| Mnemonic | Summary |
|----------|---------|
| [`VCMP`](VCMP.md) | compare two single-precision floats and update FPSCR flags (quiet on QNaN) |
| [`VCMPE`](VCMPE.md) | compare two single-precision floats; raise Invalid Operation on any NaN |
| [`VLDM`](VLDM.md) | load multiple consecutive FPU registers from memory |
| [`VLDR`](VLDR.md) | load a single-precision float from memory into an FPU register |
| [`VMOV`](VMOV.md) | move between FPU registers, between FPU and core registers, or load an immediate into an FPU register |
| [`VMRS`](VMRS.md) | move from FPU system register (FPSCR) into a core register or APSR flags |
| [`VMSR`](VMSR.md) | move a core register into an FPU system register (typically FPSCR) |
| [`VPOP`](VPOP.md) | pop FPU registers off the stack |
| [`VPUSH`](VPUSH.md) | push FPU registers onto the stack |
| [`VSTM`](VSTM.md) | store multiple consecutive FPU registers to memory |
| [`VSTR`](VSTR.md) | store a single-precision float from an FPU register to memory |

### FPU conversion & rounding

*Float ↔ int / fixed-point / half-precision, explicit rounding-mode forms (A/N/P/M/Z/X/R).*  ·  **13 instructions**

| Mnemonic | Summary |
|----------|---------|
| [`VCVT`](VCVT.md) | convert between floating-point, integer, fixed-point, and half-precision |
| [`VCVTA`](VCVTA.md) | convert float→integer, round to nearest with ties **away** from zero |
| [`VCVTM`](VCVTM.md) | convert float→integer, round toward −∞ (floor) |
| [`VCVTN`](VCVTN.md) | convert float→integer, round to nearest with ties to **even** (banker's rounding) |
| [`VCVTP`](VCVTP.md) | convert float→integer, round toward +∞ (ceiling) |
| [`VCVTR`](VCVTR.md) | convert float→integer using the current FPSCR rounding mode |
| [`VRINTA`](VRINTA.md) | round float to integral float value, ties **away** from zero |
| [`VRINTM`](VRINTM.md) | round float to integral float value, toward −∞ (floor, result stays float) |
| [`VRINTN`](VRINTN.md) | round float to integral float value, ties to **even** (banker's rounding) |
| [`VRINTP`](VRINTP.md) | round float to integral float value, toward +∞ (ceiling, result stays float) |
| [`VRINTR`](VRINTR.md) | round float to integral float using FPSCR mode, **no inexact exception** |
| [`VRINTX`](VRINTX.md) | round float to integral float using FPSCR mode, **signal inexact** |
| [`VRINTZ`](VRINTZ.md) | round float to integral float value, toward zero (truncation, result stays float) |

### System & hint

*Barriers, special-register access, interrupt mask, SVC, breakpoint, sleep hints, cache hints.*  ·  **19 instructions**

| Mnemonic | Summary |
|----------|---------|
| [`BKPT`](BKPT.md) | software breakpoint; halt to debugger or trigger DebugMonitor/HardFault |
| [`CPSID`](CPSID.md) | change processor state, disable interrupts (set PRIMASK or FAULTMASK) |
| [`CPSIE`](CPSIE.md) | change processor state, enable interrupts (clear PRIMASK or FAULTMASK) |
| [`DBG`](DBG.md) | debug hint; pass a 4-bit value to the debug architecture |
| [`DMB`](DMB.md) | data memory barrier; order memory accesses without stalling |
| [`DSB`](DSB.md) | data synchronisation barrier; wait for all prior memory accesses to complete |
| [`ISB`](ISB.md) | instruction synchronisation barrier; flush the pipeline and refetch |
| [`MRS`](MRS.md) | move from special register to general-purpose register |
| [`MSR`](MSR.md) | move from general-purpose register to special register |
| [`NOP`](NOP.md) | no operation; consume one instruction slot and do nothing |
| [`PLD`](PLD.md) | preload data; hint that a data address will be read soon |
| [`PLDW`](PLDW.md) | preload data for write (NOT available on Armv8-M) |
| [`PLI`](PLI.md) | preload instructions; hint that a code address will be executed soon |
| [`SEV`](SEV.md) | send event; set the Event Register on every core in the cluster |
| [`SVC`](SVC.md) | supervisor call; raise the SVCall exception |
| [`UDF`](UDF.md) | permanently undefined; always raises a UsageFault |
| [`WFE`](WFE.md) | wait for event; sleep until the Event Register is set |
| [`WFI`](WFI.md) | wait for interrupt; halt the core until an exception wakes it |
| [`YIELD`](YIELD.md) | hint that this thread is in a spin and could be descheduled |

### Security extension (TrustZone for Armv8-M)

*Cross-state branch, secure-gateway entry, address attribution probes.*  ·  **7 instructions**

| Mnemonic | Summary |
|----------|---------|
| [`BLXNS`](BLXNS.md) | Branch with Link and eXchange to Non-Secure |
| [`BXNS`](BXNS.md) | Branch and eXchange to Non-Secure |
| [`SG`](SG.md) | Secure Gateway: legal entry from Non-secure into Secure code |
| [`TT`](TT.md) | Test Target: query SAU/IDAU attributes of an address |
| [`TTA`](TTA.md) | Test Target Alternate domain (Secure probing Non-secure) |
| [`TTAT`](TTAT.md) | Test Target Alternate domain with T-flag (unprivileged NS view) |
| [`TTT`](TTT.md) | Test Target with T-flag (unprivileged view) |

## Alphabetical

| Mnemonic | Set | Summary |
|----------|-----|---------|
| [`ADC`](ADC.md) | base | add with carry; the building block of multi-word addition |
| [`ADD`](ADD.md) | base | add two values, optionally updating the flags |
| [`ADR`](ADR.md) | base | load a PC-relative address into a register (synthetic) |
| [`AND`](AND.md) | base | bitwise AND of two values |
| [`ASR`](ASR.md) | base | arithmetic shift right (signed divide by powers of two) |
| [`B`](B.md) | base | branch (optionally conditional) to a PC-relative label |
| [`BFC`](BFC.md) | base | clear a contiguous bit field in a register to zero |
| [`BFI`](BFI.md) | base | copy the low bits of one register into a bit field of another |
| [`BIC`](BIC.md) | base | bit clear: AND with the bitwise NOT of operand2 |
| [`BKPT`](BKPT.md) | base | software breakpoint; halt to debugger or trigger DebugMonitor/HardFault |
| [`BL`](BL.md) | base | branch with link (call a subroutine via a PC-relative label) |
| [`BLX`](BLX.md) | base | branch with link to address held in a register |
| [`BLXNS`](BLXNS.md) | Sec | Branch with Link and eXchange to Non-Secure |
| [`BX`](BX.md) | base | branch to address held in a register (no link) |
| [`BXNS`](BXNS.md) | Sec | Branch and eXchange to Non-Secure |
| [`CBNZ`](CBNZ.md) | base | compare and branch forward if register is non-zero |
| [`CBZ`](CBZ.md) | base | compare and branch forward if register is zero |
| [`CLREX`](CLREX.md) | base | clear the local exclusive monitor |
| [`CLZ`](CLZ.md) | base | count leading zero bits in a 32-bit register |
| [`CMN`](CMN.md) | base | compare negative: add and set flags, discard the result |
| [`CMP`](CMP.md) | base | compare: subtract and set flags, discard the result |
| [`CPSID`](CPSID.md) | base | change processor state, disable interrupts (set PRIMASK or FAULTMASK) |
| [`CPSIE`](CPSIE.md) | base | change processor state, enable interrupts (clear PRIMASK or FAULTMASK) |
| [`DBG`](DBG.md) | base | debug hint; pass a 4-bit value to the debug architecture |
| [`DMB`](DMB.md) | base | data memory barrier; order memory accesses without stalling |
| [`DSB`](DSB.md) | base | data synchronisation barrier; wait for all prior memory accesses to complete |
| [`EOR`](EOR.md) | base | bitwise exclusive-OR (XOR) of two values |
| [`ISB`](ISB.md) | base | instruction synchronisation barrier; flush the pipeline and refetch |
| [`IT`](IT.md) | base | If-Then: gate up to four following instructions on a condition |
| [`LDA`](LDA.md) | base | load-acquire of a 32-bit word (release/acquire ordering) |
| [`LDAB`](LDAB.md) | base | load-acquire of a byte, zero-extended (ARMv8-M) |
| [`LDAEX`](LDAEX.md) | base | load-acquire-exclusive of a 32-bit word (ARMv8-M) |
| [`LDAEXB`](LDAEXB.md) | base | load-acquire-exclusive of a byte (ARMv8-M) |
| [`LDAEXH`](LDAEXH.md) | base | load-acquire-exclusive of a half-word (ARMv8-M) |
| [`LDAH`](LDAH.md) | base | load-acquire of a half-word, zero-extended (ARMv8-M) |
| [`LDM`](LDM.md) | base | load multiple consecutive words from memory into a list of registers |
| [`LDR`](LDR.md) | base | load a 32-bit word from memory into a register |
| [`LDRB`](LDRB.md) | base | load a byte from memory, zero-extended into a 32-bit register |
| [`LDRD`](LDRD.md) | base | load two consecutive 32-bit words into a register pair |
| [`LDREX`](LDREX.md) | base | exclusive load of a 32-bit word, arming the local exclusive monitor |
| [`LDREXB`](LDREXB.md) | base | exclusive load of a byte, arming the local exclusive monitor |
| [`LDREXH`](LDREXH.md) | base | exclusive load of a half-word, arming the local exclusive monitor |
| [`LDRH`](LDRH.md) | base | load a half-word (16 bits) from memory, zero-extended into a 32-bit register |
| [`LDRSB`](LDRSB.md) | base | load a signed byte from memory, sign-extended to 32 bits |
| [`LDRSH`](LDRSH.md) | base | load a signed half-word from memory, sign-extended to 32 bits |
| [`LSL`](LSL.md) | base | logical shift left (multiply by powers of two) |
| [`LSR`](LSR.md) | base | logical shift right (unsigned divide by powers of two) |
| [`MLA`](MLA.md) | base | multiply-accumulate: `Rd = Ra + (Rn × Rm)` |
| [`MLS`](MLS.md) | base | multiply-subtract: `Rd = Ra − (Rn × Rm)` |
| [`MOV`](MOV.md) | base | copy a register or small immediate into a register |
| [`MOVS`](MOVS.md) | base | copy a register or immediate AND update N/Z (and sometimes C) |
| [`MOVT`](MOVT.md) | base | write a 16-bit immediate into the top half of a register, leaving the bottom half intact |
| [`MOVW`](MOVW.md) | base | load an arbitrary 16-bit immediate into the bottom half of a register |
| [`MRS`](MRS.md) | Sec | move from special register to general-purpose register |
| [`MSR`](MSR.md) | Sec | move from general-purpose register to special register |
| [`MUL`](MUL.md) | base | 32-bit multiply, low 32 bits of the product |
| [`MVN`](MVN.md) | base | move bitwise NOT of an immediate or register into a register |
| [`NEG`](NEG.md) | base | two's-complement negation (alias for `RSBS Rd, Rn, #0`) |
| [`NOP`](NOP.md) | base | no operation; consume one instruction slot and do nothing |
| [`ORN`](ORN.md) | base | bitwise OR with the NOT of operand2 |
| [`ORR`](ORR.md) | base | bitwise inclusive OR of two values |
| [`PKHBT`](PKHBT.md) | DSP | pack halfword: Bottom of Rn, Top of Rm (optionally shifted) |
| [`PKHTB`](PKHTB.md) | DSP | pack halfword: Top of Rn, Bottom of Rm (optionally ASR-shifted) |
| [`PLD`](PLD.md) | base | preload data; hint that a data address will be read soon |
| [`PLDW`](PLDW.md) | base | preload data for write (NOT available on Armv8-M) |
| [`PLI`](PLI.md) | base | preload instructions; hint that a code address will be executed soon |
| [`POP`](POP.md) | base | pop a list of registers from the (full-descending) stack |
| [`PUSH`](PUSH.md) | base | push a list of registers onto the (full-descending) stack |
| [`QADD`](QADD.md) | DSP | saturating signed 32-bit add |
| [`QADD16`](QADD16.md) | DSP | signed saturating per-lane add of packed halfwords |
| [`QADD8`](QADD8.md) | DSP | signed saturating per-lane add of packed bytes |
| [`QASX`](QASX.md) | DSP | signed saturating exchange-then-add-high/sub-low on packed halfwords |
| [`QDADD`](QDADD.md) | DSP | saturating "double then add" (Rd = sat(Rm + sat(2·Rn))) |
| [`QDSUB`](QDSUB.md) | DSP | saturating "double then subtract" (Rd = sat(Rm − sat(2·Rn))) |
| [`QSAX`](QSAX.md) | DSP | signed saturating exchange-then-sub-high/add-low on packed halfwords |
| [`QSUB`](QSUB.md) | DSP | saturating signed 32-bit subtract |
| [`QSUB16`](QSUB16.md) | DSP | signed saturating per-lane subtract of packed halfwords |
| [`QSUB8`](QSUB8.md) | DSP | signed saturating per-lane subtract of packed bytes |
| [`RBIT`](RBIT.md) | base | reverse the bit order of a 32-bit word |
| [`REV`](REV.md) | base | reverse byte order of a 32-bit word (endianness swap) |
| [`REV16`](REV16.md) | base | reverse byte order within each halfword of a 32-bit register |
| [`REVSH`](REVSH.md) | base | byte-swap the low halfword and sign-extend to 32 bits |
| [`ROR`](ROR.md) | base | rotate right |
| [`RRX`](RRX.md) | base | rotate right with extend (33-bit rotate through carry) |
| [`RSB`](RSB.md) | base | reverse subtract: `Rd = operand2 − Rn` |
| [`SADD16`](SADD16.md) | DSP | signed wrap-around per-lane add of packed halfwords |
| [`SADD8`](SADD8.md) | DSP | signed wrap-around per-lane add of packed bytes |
| [`SASX`](SASX.md) | DSP | signed wrap-around exchange-then-add-high/sub-low on packed halfwords |
| [`SBC`](SBC.md) | base | subtract with borrow; the building block of multi-word subtraction |
| [`SBFX`](SBFX.md) | base | extract a bit field and sign-extend it to 32 bits |
| [`SDIV`](SDIV.md) | base | signed 32-bit integer division |
| [`SEL`](SEL.md) | DSP | select bytes from Rn or Rm based on APSR.GE flags |
| [`SEV`](SEV.md) | base | send event; set the Event Register on every core in the cluster |
| [`SG`](SG.md) | Sec | Secure Gateway: legal entry from Non-secure into Secure code |
| [`SHADD16`](SHADD16.md) | DSP | signed halving per-lane add of packed halfwords |
| [`SHADD8`](SHADD8.md) | DSP | signed halving per-lane add of packed bytes |
| [`SHASX`](SHASX.md) | DSP | signed halving exchange-then-add-high/sub-low on packed halfwords |
| [`SHSAX`](SHSAX.md) | DSP | signed halving exchange-then-sub-high/add-low on packed halfwords |
| [`SHSUB16`](SHSUB16.md) | DSP | signed halving per-lane subtract of packed halfwords |
| [`SHSUB8`](SHSUB8.md) | DSP | signed halving per-lane subtract of packed bytes |
| [`SMLABB`](SMLABB.md) | DSP | Signed 16×16 multiply (bottom half of `Rn` × bottom half of `Rm`), accumulate into `Ra`. |
| [`SMLABT`](SMLABT.md) | DSP | Signed 16×16 multiply (bottom half of `Rn` × top half of `Rm`), accumulate into `Ra`. |
| [`SMLAD`](SMLAD.md) | DSP | Dual signed 16×16 multiply, then add the two products and accumulate into a 32-bit register. |
| [`SMLADX`](SMLADX.md) | DSP | Dual signed 16×16 multiply, then add the two products (with halves of the second operand exchanged) and accumulate into a 32-bit register. |
| [`SMLAL`](SMLAL.md) | base | signed multiply and accumulate into a 64-bit pair |
| [`SMLALBB`](SMLALBB.md) | DSP | Signed 16×16 multiply (bottom half of `Rn` × bottom half of `Rm`); accumulate the 32-bit product into a 64-bit `{RdHi:RdLo}` pair. |
| [`SMLALBT`](SMLALBT.md) | DSP | Signed 16×16 multiply (bottom half of `Rn` × top half of `Rm`); accumulate the 32-bit product into a 64-bit `{RdHi:RdLo}` pair. |
| [`SMLALD`](SMLALD.md) | DSP | Dual signed 16×16 multiply, then sum the two products and accumulate into a 64-bit register pair. |
| [`SMLALDX`](SMLALDX.md) | DSP | Dual signed 16×16 multiply, then sum the two products and accumulate into a 64-bit register pair (with the second operand's halves exchanged). |
| [`SMLALTB`](SMLALTB.md) | DSP | Signed 16×16 multiply (top half of `Rn` × bottom half of `Rm`); accumulate the 32-bit product into a 64-bit `{RdHi:RdLo}` pair. |
| [`SMLALTT`](SMLALTT.md) | DSP | Signed 16×16 multiply (top half of `Rn` × top half of `Rm`); accumulate the 32-bit product into a 64-bit `{RdHi:RdLo}` pair. |
| [`SMLATB`](SMLATB.md) | DSP | Signed 16×16 multiply (top half of `Rn` × bottom half of `Rm`), accumulate into `Ra`. |
| [`SMLATT`](SMLATT.md) | DSP | Signed 16×16 multiply (top half of `Rn` × top half of `Rm`), accumulate into `Ra`. |
| [`SMLAWB`](SMLAWB.md) | DSP | Signed 32-bit × 16-bit (bottom half of `Rm`) multiply, take the top 32 bits of the 48-bit product, add to `Ra`. |
| [`SMLAWT`](SMLAWT.md) | DSP | Signed 32-bit × 16-bit (top half of `Rm`) multiply, take the top 32 bits of the 48-bit product, add to `Ra`. |
| [`SMLSD`](SMLSD.md) | DSP | Dual signed 16×16 multiply, then subtract the two products and accumulate into a 32-bit register. |
| [`SMLSDX`](SMLSDX.md) | DSP | Dual signed 16×16 multiply, then subtract the two products (with halves of the second operand exchanged) and accumulate into a 32-bit register. |
| [`SMLSLD`](SMLSLD.md) | DSP | Dual signed 16×16 multiply, then difference the two products and accumulate into a 64-bit register pair. |
| [`SMLSLDX`](SMLSLDX.md) | DSP | Dual signed 16×16 multiply, then difference the two products and accumulate into a 64-bit register pair (with the second operand's halves exchanged). |
| [`SMMLA`](SMMLA.md) | DSP | Signed 32×32 multiply, add to a 32-bit value placed in the top of a 64-bit field, keep the top 32 bits. |
| [`SMMLAR`](SMMLAR.md) | DSP | Signed 32×32 multiply, add to a 32-bit value placed in the top of a 64-bit field, keep the top 32 bits (with rounding). |
| [`SMMLS`](SMMLS.md) | DSP | Signed 32×32 multiply, subtract from a 32-bit value placed in the top of a 64-bit field, keep the top 32 bits. |
| [`SMMLSR`](SMMLSR.md) | DSP | Signed 32×32 multiply, subtract from a 32-bit value placed in the top of a 64-bit field, keep the top 32 bits (with rounding). |
| [`SMMUL`](SMMUL.md) | DSP | Signed 32×32 multiply, return the top 32 bits of the 64-bit product. |
| [`SMMULR`](SMMULR.md) | DSP | Signed 32×32 multiply, return the top 32 bits of the 64-bit product (rounded — `0x80000000` is added before truncation). |
| [`SMUAD`](SMUAD.md) | DSP | Dual signed 16×16 multiply, then add the two products into a 32-bit register. |
| [`SMUADX`](SMUADX.md) | DSP | Dual signed 16×16 multiply, then add the two products (with halves of the second operand exchanged) into a 32-bit register. |
| [`SMULBB`](SMULBB.md) | DSP | Signed 16×16 multiply: bottom half of `Rn` × bottom half of `Rm` → 32-bit `Rd`. |
| [`SMULBT`](SMULBT.md) | DSP | Signed 16×16 multiply: bottom half of `Rn` × top half of `Rm` → 32-bit `Rd`. |
| [`SMULL`](SMULL.md) | base | signed 32×32 → 64-bit multiply |
| [`SMULTB`](SMULTB.md) | DSP | Signed 16×16 multiply: top half of `Rn` × bottom half of `Rm` → 32-bit `Rd`. |
| [`SMULTT`](SMULTT.md) | DSP | Signed 16×16 multiply: top half of `Rn` × top half of `Rm` → 32-bit `Rd`. |
| [`SMULWB`](SMULWB.md) | DSP | Signed 32-bit × 16-bit (bottom half of `Rm`) multiply; result is the top 32 bits of the 48-bit product. |
| [`SMULWT`](SMULWT.md) | DSP | Signed 32-bit × 16-bit (top half of `Rm`) multiply; result is the top 32 bits of the 48-bit product. |
| [`SMUSD`](SMUSD.md) | DSP | Dual signed 16×16 multiply, then subtract the two products into a 32-bit register. |
| [`SMUSDX`](SMUSDX.md) | DSP | Dual signed 16×16 multiply, then subtract the two products (with halves of the second operand exchanged) into a 32-bit register. |
| [`SSAT`](SSAT.md) | base | signed saturate a 32-bit value to N bits |
| [`SSAT16`](SSAT16.md) | DSP | signed saturate two packed halfwords in parallel |
| [`SSAX`](SSAX.md) | DSP | signed wrap-around exchange-then-sub-high/add-low on packed halfwords |
| [`SSUB16`](SSUB16.md) | DSP | signed wrap-around per-lane subtract of packed halfwords |
| [`SSUB8`](SSUB8.md) | DSP | signed wrap-around per-lane subtract of packed bytes |
| [`STL`](STL.md) | base | store-release of a 32-bit word (ARMv8-M) |
| [`STLB`](STLB.md) | base | store-release of a byte (ARMv8-M) |
| [`STLEX`](STLEX.md) | base | store-release-exclusive of a 32-bit word (ARMv8-M) |
| [`STLEXB`](STLEXB.md) | base | store-release-exclusive of a byte (ARMv8-M) |
| [`STLEXH`](STLEXH.md) | base | store-release-exclusive of a half-word (ARMv8-M) |
| [`STLH`](STLH.md) | base | store-release of a half-word (ARMv8-M) |
| [`STM`](STM.md) | base | store multiple registers to consecutive memory words |
| [`STR`](STR.md) | base | store a 32-bit word from a register to memory |
| [`STRB`](STRB.md) | base | store the low byte of a register to memory |
| [`STRD`](STRD.md) | base | store two registers as consecutive 32-bit words |
| [`STREX`](STREX.md) | base | conditional ("exclusive") store of a 32-bit word |
| [`STREXB`](STREXB.md) | base | conditional exclusive store of a byte |
| [`STREXH`](STREXH.md) | base | conditional exclusive store of a half-word |
| [`STRH`](STRH.md) | base | store the low half-word (16 bits) of a register to memory |
| [`SUB`](SUB.md) | base | subtract two values, optionally updating the flags |
| [`SVC`](SVC.md) | base | supervisor call; raise the SVCall exception |
| [`SXTAB`](SXTAB.md) | DSP | sign-extend byte from Rm and add to Rn |
| [`SXTAB16`](SXTAB16.md) | DSP | extract two bytes from Rm, sign-extend each to 16 bits, add to Rn (SIMD) |
| [`SXTAH`](SXTAH.md) | DSP | sign-extend halfword from Rm and add to Rn |
| [`SXTB`](SXTB.md) | base | sign-extend a byte from a register to 32 bits, with optional rotation |
| [`SXTB16`](SXTB16.md) | DSP | sign-extend two bytes of a register into two halfwords  + DSP |
| [`SXTH`](SXTH.md) | base | sign-extend a halfword from a register to 32 bits, with optional rotation |
| [`TBB`](TBB.md) | base | table branch byte (compact forward jump table, 8-bit offsets) |
| [`TBH`](TBH.md) | base | table branch halfword (compact forward jump table, 16-bit offsets) |
| [`TEQ`](TEQ.md) | base | test equivalence: EOR that updates flags only |
| [`TST`](TST.md) | base | test bits: AND that updates flags only |
| [`TT`](TT.md) | Sec | Test Target: query SAU/IDAU attributes of an address |
| [`TTA`](TTA.md) | Sec | Test Target Alternate domain (Secure probing Non-secure) |
| [`TTAT`](TTAT.md) | Sec | Test Target Alternate domain with T-flag (unprivileged NS view) |
| [`TTT`](TTT.md) | Sec | Test Target with T-flag (unprivileged view) |
| [`UADD16`](UADD16.md) | DSP | unsigned wrap-around per-lane add of packed halfwords |
| [`UADD8`](UADD8.md) | DSP | unsigned wrap-around per-lane add of packed bytes |
| [`UASX`](UASX.md) | DSP | unsigned wrap-around exchange-then-add-high/sub-low on packed halfwords |
| [`UBFX`](UBFX.md) | base | extract a bit field and zero-extend it to 32 bits |
| [`UDF`](UDF.md) | base | permanently undefined; always raises a UsageFault |
| [`UDIV`](UDIV.md) | base | unsigned 32-bit integer division |
| [`UHADD16`](UHADD16.md) | DSP | unsigned halving per-lane add of packed halfwords |
| [`UHADD8`](UHADD8.md) | DSP | unsigned halving per-lane add of packed bytes |
| [`UHASX`](UHASX.md) | DSP | unsigned halving exchange-then-add-high/sub-low on packed halfwords |
| [`UHSAX`](UHSAX.md) | DSP | unsigned halving exchange-then-sub-high/add-low on packed halfwords |
| [`UHSUB16`](UHSUB16.md) | DSP | unsigned halving per-lane subtract of packed halfwords |
| [`UHSUB8`](UHSUB8.md) | DSP | unsigned halving per-lane subtract of packed bytes |
| [`UMLAL`](UMLAL.md) | base | unsigned multiply and accumulate into a 64-bit pair |
| [`UMULL`](UMULL.md) | base | unsigned 32×32 → 64-bit multiply |
| [`UQADD16`](UQADD16.md) | DSP | unsigned saturating per-lane add of packed halfwords |
| [`UQADD8`](UQADD8.md) | DSP | unsigned saturating per-lane add of packed bytes |
| [`UQASX`](UQASX.md) | DSP | unsigned saturating exchange-then-add-high/sub-low on packed halfwords |
| [`UQSAX`](UQSAX.md) | DSP | unsigned saturating exchange-then-sub-high/add-low on packed halfwords |
| [`UQSUB16`](UQSUB16.md) | DSP | unsigned saturating per-lane subtract of packed halfwords |
| [`UQSUB8`](UQSUB8.md) | DSP | unsigned saturating per-lane subtract of packed bytes |
| [`USAD8`](USAD8.md) | DSP | sum of absolute differences across four bytes |
| [`USADA8`](USADA8.md) | DSP | sum of absolute differences, accumulated into a third register |
| [`USAT`](USAT.md) | base | unsigned saturate a 32-bit value to N bits |
| [`USAT16`](USAT16.md) | DSP | unsigned saturate two packed halfwords in parallel |
| [`USAX`](USAX.md) | DSP | unsigned wrap-around exchange-then-sub-high/add-low on packed halfwords |
| [`USUB16`](USUB16.md) | DSP | unsigned wrap-around per-lane subtract of packed halfwords |
| [`USUB8`](USUB8.md) | DSP | unsigned wrap-around per-lane subtract of packed bytes |
| [`UXTAB`](UXTAB.md) | DSP | zero-extend byte from Rm and add to Rn |
| [`UXTAB16`](UXTAB16.md) | DSP | extract two bytes from Rm, zero-extend each to 16 bits, add to Rn (SIMD) |
| [`UXTAH`](UXTAH.md) | DSP | zero-extend halfword from Rm and add to Rn |
| [`UXTB`](UXTB.md) | base | zero-extend a byte from a register to 32 bits, with optional rotation |
| [`UXTB16`](UXTB16.md) | DSP | zero-extend two bytes of a register into two halfwords  + DSP |
| [`UXTH`](UXTH.md) | base | zero-extend a halfword from a register to 32 bits, with optional rotation |
| [`VABS`](VABS.md) | FP | floating-point absolute value (single precision) |
| [`VADD`](VADD.md) | FP | floating-point add (single precision) |
| [`VCMP`](VCMP.md) | FP | compare two single-precision floats and update FPSCR flags (quiet on QNaN) |
| [`VCMPE`](VCMPE.md) | FP | compare two single-precision floats; raise Invalid Operation on any NaN |
| [`VCVT`](VCVT.md) | FP | convert between floating-point, integer, fixed-point, and half-precision |
| [`VCVTA`](VCVTA.md) | FP | convert float→integer, round to nearest with ties **away** from zero |
| [`VCVTM`](VCVTM.md) | FP | convert float→integer, round toward −∞ (floor) |
| [`VCVTN`](VCVTN.md) | FP | convert float→integer, round to nearest with ties to **even** (banker's rounding) |
| [`VCVTP`](VCVTP.md) | FP | convert float→integer, round toward +∞ (ceiling) |
| [`VCVTR`](VCVTR.md) | FP | convert float→integer using the current FPSCR rounding mode |
| [`VDIV`](VDIV.md) | FP | floating-point divide (single precision) |
| [`VFMA`](VFMA.md) | FP | fused multiply-add (single precision, single rounding) |
| [`VFMS`](VFMS.md) | FP | fused multiply-subtract (single precision, single rounding) |
| [`VFNMA`](VFNMA.md) | FP | fused negated multiply-add (single precision, single rounding) |
| [`VFNMS`](VFNMS.md) | FP | fused negated multiply-subtract (single precision, single rounding) |
| [`VLDM`](VLDM.md) | FP | load multiple consecutive FPU registers from memory |
| [`VLDR`](VLDR.md) | FP | load a single-precision float from memory into an FPU register |
| [`VMAXNM`](VMAXNM.md) | FP | IEEE-754-2008 floating-point maximum (single precision) |
| [`VMINNM`](VMINNM.md) | FP | IEEE-754-2008 floating-point minimum (single precision) |
| [`VMLA`](VMLA.md) | FP | floating-point multiply-accumulate (single precision, two roundings) |
| [`VMLS`](VMLS.md) | FP | floating-point multiply-subtract (single precision, two roundings) |
| [`VMOV`](VMOV.md) | FP | move between FPU registers, between FPU and core registers, or load an immediate into an FPU register |
| [`VMRS`](VMRS.md) | FP | move from FPU system register (FPSCR) into a core register or APSR flags |
| [`VMSR`](VMSR.md) | FP | move a core register into an FPU system register (typically FPSCR) |
| [`VMUL`](VMUL.md) | FP | floating-point multiply (single precision) |
| [`VNEG`](VNEG.md) | FP | floating-point negate (single precision) |
| [`VNMLA`](VNMLA.md) | FP | floating-point negated multiply-accumulate (single precision) |
| [`VNMLS`](VNMLS.md) | FP | floating-point negated multiply-subtract (single precision) |
| [`VNMUL`](VNMUL.md) | FP | floating-point negated multiply (single precision) |
| [`VPOP`](VPOP.md) | FP | pop FPU registers off the stack |
| [`VPUSH`](VPUSH.md) | FP | push FPU registers onto the stack |
| [`VRINTA`](VRINTA.md) | FP | round float to integral float value, ties **away** from zero |
| [`VRINTM`](VRINTM.md) | FP | round float to integral float value, toward −∞ (floor, result stays float) |
| [`VRINTN`](VRINTN.md) | FP | round float to integral float value, ties to **even** (banker's rounding) |
| [`VRINTP`](VRINTP.md) | FP | round float to integral float value, toward +∞ (ceiling, result stays float) |
| [`VRINTR`](VRINTR.md) | FP | round float to integral float using FPSCR mode, **no inexact exception** |
| [`VRINTX`](VRINTX.md) | FP | round float to integral float using FPSCR mode, **signal inexact** |
| [`VRINTZ`](VRINTZ.md) | FP | round float to integral float value, toward zero (truncation, result stays float) |
| [`VSEL`](VSEL.md) | FP | conditional floating-point select (single precision) |
| [`VSQRT`](VSQRT.md) | FP | floating-point square root (single precision) |
| [`VSTM`](VSTM.md) | FP | store multiple consecutive FPU registers to memory |
| [`VSTR`](VSTR.md) | FP | store a single-precision float from an FPU register to memory |
| [`VSUB`](VSUB.md) | FP | floating-point subtract (single precision) |
| [`WFE`](WFE.md) | base | wait for event; sleep until the Event Register is set |
| [`WFI`](WFI.md) | base | wait for interrupt; halt the core until an exception wakes it |
| [`YIELD`](YIELD.md) | base | hint that this thread is in a spin and could be descheduled |

## See also

- [Session 04 — Your first program](../04-first-program/README.md)
- [Session 05 — Registers and Thumb](../05-registers-and-thumb/README.md)
- [Tutorial intro](../Intro.md)

## Reference

- [*Arm®v8-M Architecture Reference Manual* (DDI 0553B)](https://developer.arm.com/documentation/ddi0553/latest)
- [*Arm® Cortex®-M33 Technical Reference Manual* (DDI 0554)](https://developer.arm.com/documentation/100230/latest)
- [Silicon Labs EFR32MG24 datasheet](https://www.silabs.com/documents/public/data-sheets/efr32mg24-datasheet.pdf)
