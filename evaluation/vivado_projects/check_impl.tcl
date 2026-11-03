# vivado -mode batch -source check_impl.tcl -tclargs <name>...: run synth+impl in each project and print the key numbers
foreach n $argv {
  open_project [file normalize [file dirname [info script]]]/proj/$n/$n.xpr
  launch_runs impl_1 -jobs 4; wait_on_run impl_1
  open_run impl_1
  set tp [get_timing_paths -max_paths 1 -setup -from [all_registers] -to [all_registers]]
  report_utilization -file [file dirname [info script]]/proj/$n/util.rpt
  puts "RESULT $n SLICE_LUT=[lindex [regexp -inline {Slice LUTs\s*\|\s*(\d+)} [report_utilization -return_string]] 1] LUT=[llength [get_cells -hier -filter {PRIMITIVE_GROUP == LUT}]] FF=[llength [get_cells -hier -filter {REF_NAME =~ FD*}]] LATCH=[llength [get_cells -hier -filter {REF_NAME == LDCE || REF_NAME == LDPE}]] delay=[get_property DATAPATH_DELAY $tp] slack=[get_property SLACK $tp]"
  close_project
}
