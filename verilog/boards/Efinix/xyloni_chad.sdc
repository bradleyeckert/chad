# PLL Constraints
#################
# T13F256 C3 gives 77 MHz max.
# The T20 eval board has a 50 MHz and 74.25 MHz oscillators.
# We want to support a 26 MHz oscillator.
# Lets target 60 MHz: 50 * (6/5) or 26 * (30/13)
# or 72 MHz: or 50 * (13/9) 26 * (36/13)
create_clock -period 16.66 [get_ports {clk}]
# create_clock -period 13.88 [get_ports {clk}]
