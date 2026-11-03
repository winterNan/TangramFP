# Export the placement of every leaf cell of a routed design: name, primitive, site, BEL.
open_checkpoint [lindex $argv 0]
set fh [open [lindex $argv 1] w]
foreach c [get_cells -hierarchical -filter {IS_PRIMITIVE && STATUS == FIXED || IS_PRIMITIVE && STATUS == PLACED}] {
  set s [get_sites -quiet -of_objects $c]
  if {$s eq ""} continue
  puts $fh "[get_property NAME $c]\t[get_property REF_NAME $c]\t$s\t[get_property BEL $c]"
}
close $fh
set fh [open [lindex $argv 2] w]
foreach t {SLICEL SLICEM} { }
foreach s [get_sites -of_objects [get_clock_regions]] { }
close $fh
