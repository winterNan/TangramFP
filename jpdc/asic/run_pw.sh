#!/bin/bash
# Gate-level (zero-delay) simulation of a Nangate45 MAC netlist on an operand trace, SAIF, OpenSTA power at 50 MHz.
# usage: run_pw.sh <tag> <tb: mac_trace_tb | mac_trace_tb_ext> <trace> <name>
cd $(dirname $0); T=$1; TB=$2; TR=$(readlink -f $3); NM=$4; H=$(pwd)
LIB=$HOME/TangramFP-jpdc/oss/nangate45/lib/NangateOpenCellLibrary_typical.lib
. ~/tools/Xilinx/Vivado/2018.3/settings64.sh
S=$H/sim_${T}_$NM; rm -rf $S; mkdir -p $S; cd $S
xvlog -nolog $H/nangate_cells.v $H/n_$T.v > xvlog.out 2>&1
xvhdl -nolog $H/../hw16/tb/$TB.vhd > xvhdl.out 2>&1
xelab -nolog -debug typical -generic_top "trace=$TR" -generic_top "outfile=$S/out.txt" $TB -s snap > xelab.out 2>&1 || { tail -5 xelab.out; exit 1; }
cat > sim.tcl <<EOT
open_saif $S/act.saif
log_saif [get_objects -r /$TB/dut/*]
run all
close_saif
quit
EOT
xsim -nolog snap -tclbatch sim.tcl > xsim.out 2>&1
grep -c "^ *([^ ]*/[^ ]* (T0" $S/act.saif > $S/dropped_nets.txt; sed -i "/^ *([^ ]*\/[^ ]* (T0/d" $S/act.saif
cd $H; NET=n_$T.v LIB=$LIB PERIOD=20 SAIF=$S/act.saif SCOPE=$TB/dut ~/eda/bin/sta -no_splash -exit sta.tcl > $S/power.txt 2>&1
echo "$T $NM total_mW $(grep "^Total" $S/power.txt | awk "{printf \"%.4f\", \$5*1000}") seq_comb $(grep "^Sequential\|^Combinational" $S/power.txt | awk "{printf \"%s=%.4f \", \$1, \$5*1000}")"
grep -q "^Total" $S/power.txt && rm -f $S/act.saif
