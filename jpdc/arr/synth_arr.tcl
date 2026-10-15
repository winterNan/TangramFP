# vivado -mode batch -source synth_arr.tcl -tclargs <outdir> <period_ns> <N> <tangram> <corr> <srcdir> <netlist 0/1>
# Out-of-context place and route of an N x N array of FP16 MACs on a Kintex-7 (-2).
set out [lindex $argv 0]; set per [lindex $argv 1]; set N [lindex $argv 2]; set tg [lindex $argv 3]
set corr [lindex $argv 4]; set srcd [lindex $argv 5]; set nl [lindex $argv 6]
set dir [expr {[llength $argv] > 7 ? [lindex $argv 7] : "Default"}]
file mkdir $out
set_param general.maxThreads 4
read_vhdl [glob $srcd/*.vhd]
synth_design -top sarray -part xc7k160tffg676-2 -mode out_of_context -flatten_hierarchy rebuilt -generic N=$N -generic tangram=$tg -generic corr=$corr -generic use_bufg=1
create_clock -name clk -period $per [get_ports clk]
set_input_delay 0 -clock clk [get_ports {a[*] w[*] clr[*] n_rst}]
opt_design; place_design -directive $dir; phys_opt_design; route_design
report_utilization -file $out/util.rpt
report_utilization -hierarchical -hierarchical_depth 4 -file $out/util_hier.rpt
report_timing_summary -max_paths 5 -file $out/timing.rpt
set hp [get_timing_paths -hold -max_paths 1]
set fh [open $out/summary.txt w]
set tp [get_timing_paths -max_paths 1 -setup]
puts $fh "N=$N tangram=$tg corr=$corr period=$per src=$srcd LUT=[llength [get_cells -hier -filter {PRIMITIVE_GROUP == LUT}]] FF=[llength [get_cells -hier -filter {REF_NAME =~ FD*}]] LATCH=[llength [get_cells -hier -filter {REF_NAME == LDCE || REF_NAME == LDPE}]] CARRY4=[llength [get_cells -hier -filter {REF_NAME == CARRY4}]]"
puts $fh "worst: delay=[get_property DATAPATH_DELAY $tp] slack=[get_property SLACK $tp] from=[get_property STARTPOINT_PIN $tp] to=[get_property ENDPOINT_PIN $tp]"
puts $fh "hold: slack=[get_property SLACK $hp]"
close $fh
if {$nl} {
  write_checkpoint -force $out/routed.dcp
  write_verilog -force -mode timesim -sdf_anno true $out/timesim.v
  write_sdf -force $out/timesim.sdf
}
