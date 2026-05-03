# Session 10 — Subroutines & AAPCS

> **Goal:** factor our blink program into proper functions (`led_init`, `led_on`, `led_off`, `delay_ms`) and learn the rules of how functions call each other on ARM.

We've been writing one giant `reset_handler` that does everything. That's fine for tiny demos, but real programs need **subroutines** — chunks of code we can call by name. Doing this well requires following a small set of rules called **AAPCS**.

---

## What's AAPCS?

**AAPCS** = **A**rm **A**rchitecture **P**rocedure **C**all **S**tandard. It's the contract every ARM function obeys, so that hand-written assembly, compiler-generated C, and library code all play nicely together. We'll use the simplified Cortex-M flavour.

The four rules to know:

1. **Arguments go in `r0`, `r1`, `r2`, `r3`** (in that order). Beyond four, they spill to the stack.
2. **Return value is in `r0`** (or `r0`/`r1` for 64-bit).
3. **`r0`–`r3` and `r12` are caller-saved** ("scratch") — a callee can clobber them freely. If you cared about their values, save them yourself before calling.
4. **`r4`–`r11` are callee-saved** — if a function uses them, it must `push` them on entry and `pop` them on exit.

Plus two registers with fixed roles:

- **`lr` (r14)** holds the return address. Every function ends with something equivalent to `bx lr`.
- **`sp` (r13)** must always be 8-byte aligned at function-call boundaries. Always push and pop in pairs.

> **Why?:** Because if you ever call a C function (or a C function calls *your* assembly), both sides need to agree on who keeps which register intact. AAPCS is that agreement.

---

## How `bl` and `bx` work

`bl target` ("branch with link"):

1. Sets `lr = pc + 4` (the address of the instruction after `bl`),
2. Branches to `target`.

`bx lr` ("branch and exchange") jumps to whatever address is in `lr`. So a minimal function is:

```asm
my_func:
    @ ... do stuff ...
    bx  lr
```

If `my_func` itself calls another function with `bl`, that overwrites `lr` — so you need to save it before:

```asm
my_func:
    push    {lr}            @ save return address
    @ ... do stuff including bl ...
    pop     {pc}            @ pop saved lr directly into pc -> return
```

`pop {pc}` is a slick trick: instead of popping into `lr` then `bx lr`, you just pop straight into the program counter. Same effect, one instruction.

---

## A function that uses callee-saved registers

If a function uses `r4`–`r11`, it must restore them. The standard prologue/epilogue:

```asm
my_func:
    push    {r4, r5, r6, lr}     @ prologue
    @ ... use r4, r5, r6 freely ...
    pop     {r4, r5, r6, pc}     @ epilogue (returns)
```

> **Gotcha:** keep your `push`/`pop` lists in sync. Push the same registers in `pop`, in the same order. If you push 3 registers and pop 4, you'll wreck the stack and crash.

---

## Refactored blink

In [`main.s`](./main.s) we split the program into:

```
reset_handler          calls led_init, then loops calling led_on/off + delay_ms
led_init               configure GPIO clock + PC1 push-pull
led_on                 clear PC1 in DOUT
led_off                set PC1 in DOUT
delay_ms(uint32_t ms)  same SysTick routine from Session 8 (callee-saved discipline added)
```

Build and flash:

```sh
make
make flash
```

Same blink, far cleaner code. From here on, every new feature is a new function — not another 30 lines crammed into `reset_handler`.

---

## Try it

- Add `led_red_on` / `led_green_on` / `led_blue_on` and write a `reset_handler` that cycles through R → G → B every 500 ms.
- Add a function `set_rgb(uint32_t mask)` that drives all three LEDs from a single 3-bit argument in `r0`. (Now you're using AAPCS to pass an argument.)
- Disassemble with `make disasm` and find your function prologues/epilogues. You should see `push {r4, ..., lr}` at entry and `pop {..., pc}` at exit.

---

## What you should remember

- **Args in `r0`–`r3`. Return in `r0`. Save `r4`–`r11` if you use them.**
- `bl` sets `lr` and branches; `bx lr` returns.
- Standard prologue: `push {r4, ..., lr}`. Standard epilogue: `pop {r4, ..., pc}`.
- Keep `sp` 8-byte aligned at call sites — push/pop in pairs of 32-bit registers.

---

➡️ **Next:** [Session 11 — Interrupts](../11-interrupts/)
