# Power of the sequential groups (env GRP prefix) after the usual report.
source sta_w.tcl
foreach k {st2 ff lat} {
  set f [open "$env(GRP)_$k.txt"]; set names [string trim [read $f]]; close $f
  if {$names eq ""} { puts "GROUP $k 0 0.0"; continue }
  set cells [get_cells $names]
  set tot 0.0
  foreach c $cells { set p [sta::instance_power $c [sta::cmd_corner]]; set tot [expr {$tot + [lindex $p 3]}] }
  puts "GROUP $k [llength $cells] $tot"
}
