# Analysis-only virtual clock for standalone OS/WS accelerator cores.
# This is NOT a board pin constraint or a measured Fmax.
create_clock -name core_clk -period 10.000 [get_ports clk]
