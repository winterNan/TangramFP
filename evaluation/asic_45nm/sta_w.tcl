# OpenSTA for the complete MAC: register-to-register timing (and power when SAIF is given).
# env: NET, LIB, PERIOD (ns), [SAIF, SCOPE], [LATCH_TRANSPARENT=1: treat isolation latches as transparent]
read_liberty $env(LIB)
read_verilog $env(NET)
link_design MACW
create_clock -name clk -period $env(PERIOD) [get_ports clk]
set_input_delay 0 -clock clk [get_ports {a[*] b[*] c[*] n_rst}]
if {[info exists env(LATCH_TRANSPARENT)]} {
  set g [get_pins -of_objects [get_cells -filter "ref_name =~ DLH_*"] -filter "direction == input && name == G"]
  puts "latch enable pins: [llength $g]"
  set_case_analysis 1 $g
}
report_checks -path_delay max -digits 3 -fields {} -from [all_registers -clock_pins] -to [all_registers -data_pins]
if {[info exists env(SAIF)]} { read_saif -scope $env(SCOPE) $env(SAIF); report_activity_annotation; report_power }
