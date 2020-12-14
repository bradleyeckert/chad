create_clock -period 83.333 -name clk_in [get_ports {clk_in}]
derive_pll_clocks
