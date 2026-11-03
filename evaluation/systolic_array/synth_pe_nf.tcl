# vivado -mode batch -source synth_pe_nf.tcl -tclargs <outdir> <period_ns> <tangram> <corr> <srcdir>
# Out-of-context place and route of one PE of the array (rtl/array) with its
# hierarchy kept, for the per-function placement figure; exports every placed cell to <outdir>/place.tsv.
set out [lindex $argv 0]; set per [lindex $argv 1]; set tg [lindex $argv 2]; set corr [lindex $argv 3]; set srcd [lindex $argv 4]
file mkdir $out
set_param general.maxThreads 2
foreach f {tools LZC CSA2i csa_4i DaddaMultiplier fp_add kacy_mult mode_sel MAC pe} { read_vhdl $srcd/$f.vhd }
synth_design -top PE -part xc7k160tffg676-2 -mode out_of_context -flatten_hierarchy none -generic tangram=$tg -generic corr=$corr
create_clock -name clk -period $per [get_ports clk]
set_input_delay 0 -clock clk [get_ports {a_in[*] w_in[*] clr_in n_rst}]
opt_design; place_design -directive Default; phys_opt_design; route_design
report_utilization -hierarchical -file $out/util_hier.rpt
report_timing_summary -max_paths 3 -file $out/timing.rpt
set fh [open $out/summary.txt w]
puts $fh "PE tangram=$tg corr=$corr src=$srcd LUT=[llength [get_cells -hier -filter {PRIMITIVE_GROUP == LUT}]] FF=[llength [get_cells -hier -filter {REF_NAME =~ FD*}]] CARRY4=[llength [get_cells -hier -filter {REF_NAME == CARRY4}]]"
close $fh
write_checkpoint -force $out/routed.dcp
set fh [open $out/place.tsv w]
foreach c [get_cells -hierarchical -filter {IS_PRIMITIVE && STATUS == FIXED || IS_PRIMITIVE && STATUS == PLACED}] {
  set s [get_sites -quiet -of_objects $c]
  if {$s eq ""} continue
  puts $fh "[get_property NAME $c]\t[get_property REF_NAME $c]\t$s\t[get_property BEL $c]"
}
close $fh
