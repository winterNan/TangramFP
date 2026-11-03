# vivado -mode batch -source synth_w.tcl -tclargs <outdir> <period_ns> <tangram> <corr> <place_directive>
# Out-of-context place and route of one complete MAC (MACW, rtl/mac) on a Kintex-7 (-2).
set out [lindex $argv 0]; set per [lindex $argv 1]; set tg [lindex $argv 2]; set corr [lindex $argv 3]; set dir [lindex $argv 4]
file mkdir $out
set_param general.maxThreads 2
foreach f {tools LZC CSA2i csa_4i DaddaMultiplier fp_add kacy_mult mode_sel MAC macw} { read_vhdl ../rtl/mac/$f.vhd }
synth_design -top MACW -part xc7k160tffg676-2 -mode out_of_context -flatten_hierarchy rebuilt -generic tangram=$tg -generic corr=$corr
create_clock -name clk -period $per [get_ports clk]
set_input_delay 0 -clock clk [get_ports {a[*] b[*] c[*] n_rst}]
opt_design; place_design -directive $dir; phys_opt_design; route_design
report_utilization -hierarchical -file $out/util_hier.rpt
report_timing_summary -max_paths 3 -file $out/timing.rpt
set tp [get_timing_paths -max_paths 1 -setup -from [all_registers] -to [all_registers]]
set fh [open $out/summary.txt w]
puts $fh "tangram=$tg corr=$corr dir=$dir LUT=[llength [get_cells -hier -filter {PRIMITIVE_GROUP == LUT}]] FF=[llength [get_cells -hier -filter {REF_NAME =~ FD*}]] LATCH=[llength [get_cells -hier -filter {REF_NAME == LDCE || REF_NAME == LDPE}]] CARRY4=[llength [get_cells -hier -filter {REF_NAME == CARRY4}]]"
puts $fh "reg2reg: delay=[get_property DATAPATH_DELAY $tp] slack=[get_property SLACK $tp] from=[get_property STARTPOINT_PIN $tp] to=[get_property ENDPOINT_PIN $tp]"
close $fh
write_checkpoint -force $out/routed.dcp
write_verilog -force -mode timesim -sdf_anno true $out/timesim.v
write_sdf -force $out/timesim.sdf
