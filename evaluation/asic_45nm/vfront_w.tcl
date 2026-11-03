# VHDL front end for the complete MAC (MACW): Vivado elaboration and mapping, Verilog netlist of Xilinx primitives.
# vivado -mode batch -source vfront_w.tcl -tclargs <out.v> <tangram> <corr>
set out [lindex $argv 0]; set t [lindex $argv 1]; set c [lindex $argv 2]
foreach f {tools LZC CSA2i csa_4i DaddaMultiplier fp_add kacy_mult mode_sel MAC macw} { read_vhdl ../rtl/mac/$f.vhd }
synth_design -top MACW -part xc7k160tffg676-2 -mode out_of_context -flatten_hierarchy full -generic tangram=$t -generic corr=$c
write_verilog -force -mode funcsim $out
