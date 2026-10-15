# vivado -mode batch -source synth_fpnew.tcl -tclargs <outdir> <period_ns>
set out [lindex $argv 0]; set per [lindex $argv 1]; set maxdsp [lindex $argv 2]
set R cvfpu/src
file mkdir $out
read_verilog -sv [list $R/fpnew_pkg.sv $R/common_cells/src/cf_math_pkg.sv $R/common_cells/src/lzc.sv \
    $R/fpnew_classifier.sv $R/fpnew_rounding.sv $R/fpnew_fma.sv fpnew_mac16.sv]
synth_design -top MAC -part xc7k160tffg676-2 -mode out_of_context -flatten_hierarchy none -include_dirs $R/common_cells/include -max_dsp $maxdsp
create_clock -name clk -period $per [get_ports clk]
set_input_delay 0 -clock clk [get_ports {a[*] b[*] c[*] n_rst}]
opt_design; place_design; phys_opt_design; route_design
report_utilization -file $out/util.rpt
report_timing -max_paths 1 -file $out/worst.rpt
set fh [open $out/summary.txt w]
set tp [get_timing_paths -max_paths 1]
puts $fh "fpnew_fma_fp16 period=$per LUT=[llength [get_cells -hier -filter {PRIMITIVE_GROUP == LUT}]] FF=[llength [get_cells -hier -filter {REF_NAME =~ FD*}]] LATCH=[llength [get_cells -hier -filter {REF_NAME == LDCE}]] CARRY4=[llength [get_cells -hier -filter {REF_NAME == CARRY4}]] DSP=[llength [get_cells -hier -filter {REF_NAME =~ DSP*}]]"
puts $fh "worst: delay=[get_property DATAPATH_DELAY $tp] slack=[get_property SLACK $tp] from=[get_property STARTPOINT_PIN $tp] to=[get_property ENDPOINT_PIN $tp]"
close $fh
write_checkpoint -force $out/routed.dcp
write_verilog -force -mode timesim -sdf_anno true $out/timesim.v
write_sdf -force $out/timesim.sdf
