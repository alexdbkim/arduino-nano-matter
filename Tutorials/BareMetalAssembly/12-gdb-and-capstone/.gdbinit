# .gdbinit — auto-connect arm-none-eabi-gdb to OpenOCD for this project.
# Start the server in another terminal first (`make gdbserver` from this folder),
# which uses the Silicon Labs–forked OpenOCD:
#   $SILABS_OOCD/bin/openocd -s $SILABS_OOCD/share/openocd/scripts \
#                            -f interface/cmsis-dap.cfg -f target/efm32s2_g23.cfg

file main.elf
target extended-remote :3333
monitor reset halt
set confirm off
set print pretty on
display/i $pc
