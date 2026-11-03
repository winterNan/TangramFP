#!/bin/bash
# Zero-delay gate-level simulation of a Nangate45 MACW netlist on a trace, SAIF, OpenSTA power at 50 MHz; RTL check.
# usage: run_pw_w.sh <tag> <tangram> <corr> <workload>
cd $(dirname $0); T=$1; G=$2; C=$3; M=$4; H=$(pwd); TR=$(readlink -f ../traces/net_$M.txt)
LIB=$NANGATE45_LIB
. ../env.sh
R=$H/../fpga_mac/rtl_t${G}_c${C}_$M.txt; [ -f $R ] || ../fpga_mac/rtl_macw.sh $G $C $TR $R
S=$H/simw_${T}_$M; mkdir -p "$S"; cd "$S" || exit 1
xvlog -nolog $H/nangate_cells.v $H/nw_$T.v > xvlog.out 2>&1
xvhdl -nolog $H/../rtl/tb/macw_tb.vhd > xvhdl.out 2>&1
xelab -nolog -debug typical -generic_top "trace=$TR" -generic_top "outfile=$S/out.txt" macw_tb -s snap > xelab.out 2>&1 || { tail -3 xelab.out; exit 1; }
printf "open_saif $S/act.saif\nlog_saif [get_objects -r /macw_tb/dut/*]\nrun all\nclose_saif\nquit\n" > sim.tcl
xsim -nolog snap -tclbatch sim.tcl > xsim.out 2>&1
grep -c '^ *([^ ]*/[^ ]* (T0' act.saif > dropped_nets.txt; sed -i '/^ *([^ ]*\/[^ ]* (T0/d' act.saif
(cd $H && NET=nw_$T.v LIB=$LIB PERIOD=20 SAIF=$S/act.saif SCOPE=macw_tb/dut $EDA_BIN/sta -no_splash -exit sta_w.tcl > $S/power.txt 2>&1)
x=$(paste -d" " out.txt $R | awk '{n++; if ($1!=$3 || $2!=$4) {x++; last=n}} END {print x+0, "last", last+0}')
echo "$T $M total_mW $(grep '^Total' power.txt | awk '{printf "%.4f", $5*1000}') unannotated $(grep -m1 unannotated power.txt | awk '{print $2}') mismatch $x" >> $H/asicw_power.txt
grep -q '^Total' power.txt && rm -rf act.saif xsim.dir snap.wdb
