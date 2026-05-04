# .gdbinit — auto-connect arm-none-eabi-gdb to OpenOCD for this project.
# Start the server in another terminal first:
#   openocd -f interface/cmsis-dap.cfg -f target/efm32s2.cfg
# (or just `make gdbserver` from this folder).

file main.elf
target extended-remote :3333
monitor reset halt
set confirm off
set print pretty on
display/i $pc
