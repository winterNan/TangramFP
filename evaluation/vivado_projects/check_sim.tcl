# vivado -mode batch -source check_sim.tcl -tclargs <name>...: run the project's behavioural simulation to the end
foreach n $argv {
  open_project [file normalize [file dirname [info script]]]/proj/$n/$n.xpr
  launch_simulation; run all; close_sim
  puts "SIMDONE $n"
  close_project
}
