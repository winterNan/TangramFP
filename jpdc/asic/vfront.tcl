# VHDL front end: elaborate and map one MAC variant with Vivado, write a Verilog netlist of Xilinx primitives.
# vivado -mode batch -source vfront.tcl -tclargs <out.v> <gating> <corr>
set out [lindex $argv 0]; set g [lindex $argv 1]; set c [lindex $argv 2]
foreach f {tools LZC CSA2i csa_4i DaddaMultiplier fp_add kacy_mult mode_sel MAC} { read_vhdl ../arr/src2/$f.vhd }
synth_design -top MAC -part xc7k160tffg676-2 -mode out_of_context -flatten_hierarchy full -generic gating=$g -generic corr=$c
write_verilog -force -mode funcsim $out
