# .gdbinit — auto-connect arm-none-eabi-gdb to JLinkGDBServer for this project.
# Start the server in another terminal first:
#   JLinkGDBServer -device EFR32MG24BxxxF1536 -if SWD -speed 4000

file main.elf
target remote :2331
monitor reset
monitor halt
set confirm off
set print pretty on
display/i $pc
