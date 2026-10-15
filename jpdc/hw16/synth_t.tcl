# vivado -mode batch -source synth_t.tcl -tclargs <outdir> <period_ns> <gating> <corr>
# Timing view: latch-free RTL (src_t), so that static timing covers every input-to-register path.
set out [lindex $argv 0]; set per [lindex $argv 1]; set gating [lindex $argv 2]; set corr [lindex $argv 3]
file mkdir $out
read_vhdl [glob src_t/*.vhd]
synth_design -top MAC -part xc7k160tffg676-2 -mode out_of_context -flatten_hierarchy none -generic gating=$gating -generic corr=$corr
create_clock -name clk -period $per [get_ports clk]
set_input_delay 0 -clock clk [get_ports {a[*] b[*] c[*] n_rst}]
opt_design; place_design; phys_opt_design; route_design
set fh [open $out/summary.txt w]
set lat [get_cells -hier -filter {REF_NAME == LDCE || REF_NAME == LDPE}]
puts $fh "gating=$gating corr=$corr period=$per LUT=[llength [get_cells -hier -filter {PRIMITIVE_GROUP == LUT}]] LATCH=[llength $lat] CARRY4=[llength [get_cells -hier -filter {REF_NAME == CARRY4}]]"
foreach c {msel kacy fp_add} { puts $fh "cells_$c: LUT=[llength [get_cells -hier -filter "PRIMITIVE_GROUP == LUT && NAME =~ $c/*"]]" }
set tp [get_timing_paths -max_paths 1]
puts $fh "worst: delay=[get_property DATAPATH_DELAY $tp] slack=[get_property SLACK $tp] from=[get_property STARTPOINT_PIN $tp] to=[get_property ENDPOINT_PIN $tp]"
report_timing -max_paths 1 -file $out/worst.rpt
foreach {nm obj} [list mult [get_cells kacy] msel [get_cells -quiet msel]] {
    if {![llength $obj]} continue
    set tp [get_timing_paths -through $obj -max_paths 1]
    if {[llength $tp]} { puts $fh "through_$nm: delay=[get_property DATAPATH_DELAY $tp] slack=[get_property SLACK $tp] from=[get_property STARTPOINT_PIN $tp] to=[get_property ENDPOINT_PIN $tp]" }
    report_timing -through $obj -max_paths 1 -file $out/through_$nm.rpt
}
# latest arrival at the pins of the multiplier instance: its operand inputs (u, v) and its mode input
foreach {nm pat} {arr_mode kacy/mode[*] arr_u kacy/u[*] arr_v kacy/v[*] arr_out kacy/mantissa[*]} {
    set pins [get_pins -quiet $pat]
    if {![llength $pins]} { puts $fh "$nm: no pins"; continue }
    set worst -1; set wp ""
    foreach p $pins {
        set tp [get_timing_paths -quiet -through $p -max_paths 1]
        if {![llength $tp]} continue
        # arrival at the pin = total delay of the worst path through it minus the worst delay from the pin to the endpoint
        set rpt [report_timing -through $p -max_paths 1 -return_string]
        set arr ""
        foreach line [split $rpt "\n"] {
            if {[regexp {^\s+net \(fo=\d+, (routed|unplaced|estimated|unset)\)\s+([\d.]+)\s+([\d.]+)\s+(\S+)} $line -> t incr path net]} {
                if {[string match "*[lindex [split $p /] end]*" $net] || $arr eq ""} { }
            }
        }
        set d [get_property DATAPATH_DELAY $tp]
        if {$d > $worst} { set worst $d; set wp $p }
    }
    puts $fh "$nm: worst_total_through=$worst pin=$wp"
    if {$wp ne ""} { report_timing -through $wp -max_paths 1 -file $out/$nm.rpt }
}
close $fh
report_utilization -hierarchical -file $out/util_hier.rpt
