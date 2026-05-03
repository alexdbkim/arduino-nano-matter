# Session 09 — Reading a button

> **Goal:** read the on-board user button (PA0) and make the red LED follow it. Press = LED on. Release = LED off.

We add three new ideas to what we already know:

1. Configuring a GPIO pin as an **input** instead of an output.
2. Using an internal **pull-up resistor** so the line has a known value when the button isn't pressed.
3. **Polling** the input — reading `DIN` in a loop.

---

## How a momentary button is wired

The Nano Matter's user button connects PA0 to **ground** when pressed. When *not* pressed, the pin is floating — its voltage is undefined and could read anything.

To get a deterministic "not pressed" reading we ask the chip to add a weak **pull-up** resistor inside the package: when the button is open, the pull-up keeps PA0 at 3.3 V (HIGH). When the button is pressed, it shorts PA0 to ground (LOW), overriding the weak pull-up.

Result:

| Button | Pin reads |
|---|---|
| not pressed | 1 (HIGH) |
| pressed | 0 (LOW) |

So **pressed = 0**. The button is "active low", just like the LEDs.

---

## GPIO mode values you'll meet

The 4-bit mode field has many possible values. The ones we'll use most:

| Mode | Name | What it does |
|---|---|---|
| `0x0` | DISABLED | Pin is electrically disconnected (default after reset) |
| `0x1` | INPUT | High-impedance input. No pull-up/pull-down. |
| `0x3` | INPUTPULL | Input with internal pull. **DOUT bit selects up (1) or down (0).** |
| `0x4` | PUSHPULL | Output, can drive HIGH or LOW. |

For our button: mode = `0x3`, **and** we must set the corresponding `DOUT` bit to `1` to choose a pull-**up** (rather than pull-**down**).

---

## The plan

```text
init:
    enable GPIO clock
    PC1: push-pull output                      (LED, as before)
    PA0: INPUTPULL, DOUT[0]=1                  (button with pull-up)
loop:
    read PA_DIN
    if bit 0 of PA_DIN is 0:    # button pressed
        clear bit 1 of PC_DOUT  # LED on  (active low!)
    else:
        set bit 1 of PC_DOUT    # LED off
    goto loop
```

The full source is in [`main.s`](./main.s). Build, flash, then press and hold the small `USR` button on the board. The red LED should light up while you're pressing it and turn off when you release.

> **Try it:**
> - Invert the logic so the LED is on when the button is *not* pressed (release-to-blink).
> - Read PA0 from GDB while halted: `x/wx 0x4003C044` shows the whole `Port A DIN`. Press the button, halt, read again — bit 0 changes.
> - Use the button to toggle the LED only on a press *edge* (transition from 1 to 0). You'll need to remember the previous state.

---

## Why polling is "fine for now" but not great

Our loop reads the button millions of times per second and does basically nothing else. That's wasteful: the CPU is fully awake for no reason, burning battery on a real device. The proper fix is to use **interrupts**: configure the chip to wake the CPU only when the button changes. That's exactly what Session 11 does.

For now, polling is the simplest thing that works.

---

## What you should remember

- Inputs need a configured **mode** (`0x1` plain input, `0x3` input-with-pull).
- For mode `0x3`, the `DOUT` bit chooses **pull-up (1)** or **pull-down (0)**.
- Read input state from the port's **`DIN`** register (offset `+0x14` for EFR32MG24 GPIO).
- Active-low buttons read **0** when pressed, **1** when released.

---

➡️ **Next:** [Session 10 — Subroutines & AAPCS](../10-subroutines-and-aapcs/)
