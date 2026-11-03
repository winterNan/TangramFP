create_clock -name clk -period 20.000 [get_ports clk]
set_input_delay 0 -clock clk [get_ports {a[*] w[*] clr[*] n_rst}]
