# vivado -mode batch -source power.tcl -tclargs <outdir> <saif> <tag>
set out [lindex $argv 0]; set saif [lindex $argv 1]; set tag [lindex $argv 2]; set tb [expr {[llength $argv] > 3 ? [lindex $argv 3] : "mac_trace_tb"}]
open_checkpoint $out/routed.dcp
read_saif -strip_path $tb/dut $saif
report_power -file $out/power_$tag.rpt -hier all -hierarchical_depth 3
report_power -format xml -file $out/power_$tag.xml
