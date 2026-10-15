# OpenSTA: timing of one synthesized MAC (and vectorless power unless an activity file is given).
# sta -no_splash -exit sta.tcl   with env NET, LIB, PERIOD (ns), [SAIF]
read_liberty $env(LIB)
read_verilog $env(NET)
link_design MAC
create_clock -name clk -period $env(PERIOD) [get_ports clk]
set_input_delay 0 -clock clk [get_ports {a[*] b[*] c[*] n_rst mode_in[*]}]
set_output_delay 0 -clock clk [get_ports {sumout[*]}]
report_checks -path_delay max -digits 3 -fields {}
if {[info exists env(SAIF)]} { read_saif -scope $env(SCOPE) $env(SAIF) }
report_activity_annotation
report_power
