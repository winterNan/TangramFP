# vivado -mode batch -source synth.tcl -tclargs <outdir> <period_ns> <gating> <corr>
# Out-of-context place and route of one FP16 MAC (original RTL plus generics) on a Kintex-7, speed grade -2.
# Produces utilization, a routed checkpoint and a timing-simulation netlist for the power runs.
# Static timing of this netlist is NOT meaningful: the timer cuts paths at the latches (see synth_t.tcl).
set out [lindex $argv 0]; set per [lindex $argv 1]; set gating [lindex $argv 2]; set corr [lindex $argv 3]
file mkdir $out
read_vhdl [glob src/*.vhd]
synth_design -top MAC -part xc7k160tffg676-2 -mode out_of_context -flatten_hierarchy none -generic gating=$gating -generic corr=$corr
create_clock -name clk -period $per [get_ports clk]
set_input_delay 0 -clock clk [get_ports {a[*] b[*] c[*] n_rst}]
opt_design; place_design; phys_opt_design; route_design
report_utilization -file $out/util.rpt
report_utilization -hierarchical -file $out/util_hier.rpt
set fh [open $out/summary.txt w]
set lat [get_cells -hier -filter {REF_NAME == LDCE || REF_NAME == LDPE}]
puts $fh "gating=$gating corr=$corr LUT=[llength [get_cells -hier -filter {PRIMITIVE_GROUP == LUT}]] FF=[llength [get_cells -hier -filter {REF_NAME =~ FD*}]] LATCH=[llength $lat] CARRY4=[llength [get_cells -hier -filter {REF_NAME == CARRY4}]]"
foreach c {msel kacy fp_add} { puts $fh "cells_$c: LUT=[llength [get_cells -hier -filter "PRIMITIVE_GROUP == LUT && NAME =~ $c/*"]] LATCH=[llength [get_cells -hier -filter "(REF_NAME == LDCE || REF_NAME == LDPE) && NAME =~ $c/*"]]" }
puts $fh "cells_top: LATCH=[llength [get_cells -filter {REF_NAME == LDCE || REF_NAME == LDPE}]]"
close $fh
write_checkpoint -force $out/routed.dcp
write_verilog -force -mode timesim -sdf_anno true $out/timesim.v
write_sdf -force $out/timesim.sdf
