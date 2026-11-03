# vivado -mode batch -source synth_fpnew_w.tcl -tclargs <outdir> <period_ns> <inreg> <place_directive>
# FPnew FP16 FMA as a complete MAC (MACW ports) in the flow of fpga_mac/synth_w.tcl; no DSP blocks, like our MACs.
set out [lindex $argv 0]; set per [lindex $argv 1]; set inreg [lindex $argv 2]; set dir [lindex $argv 3]
set R cvfpu/src
file mkdir $out
set_param general.maxThreads 2
read_verilog -sv [list $R/fpnew_pkg.sv $R/common_cells/src/cf_math_pkg.sv $R/common_cells/src/lzc.sv \
    $R/fpnew_classifier.sv $R/fpnew_rounding.sv $R/fpnew_fma.sv fpnew_macw.sv]
synth_design -top MACW -part xc7k160tffg676-2 -mode out_of_context -flatten_hierarchy rebuilt -include_dirs $R/common_cells/include -max_dsp 0 -generic INREG=$inreg
create_clock -name clk -period $per [get_ports clk]
set_input_delay 0 -clock clk [get_ports {a[*] b[*] c[*] n_rst}]
opt_design; place_design -directive $dir; phys_opt_design; route_design
report_utilization -file $out/util.rpt
report_timing_summary -max_paths 3 -file $out/timing.rpt
set tp [get_timing_paths -max_paths 1 -setup -from [all_registers] -to [all_registers]]
set fh [open $out/summary.txt w]
puts $fh "fpnew inreg=$inreg dir=$dir FF=[llength [get_cells -hier -filter {REF_NAME =~ FD*}]] DSP=[llength [get_cells -hier -filter {REF_NAME =~ DSP*}]]"
if {[llength $tp]} { puts $fh "reg2reg: delay=[get_property DATAPATH_DELAY $tp] slack=[get_property SLACK $tp] from=[get_property STARTPOINT_PIN $tp] to=[get_property ENDPOINT_PIN $tp]" } else { set tp [get_timing_paths -max_paths 1 -setup]; puts $fh "in2reg: delay=[get_property DATAPATH_DELAY $tp] slack=[get_property SLACK $tp]" }
close $fh
write_checkpoint -force $out/routed.dcp
write_verilog -force -mode timesim -sdf_anno true $out/timesim.v
write_sdf -force $out/timesim.sdf
