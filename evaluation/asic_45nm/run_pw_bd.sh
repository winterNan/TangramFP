#!/bin/bash
# As run_pw_w.sh, plus power of the stage-2 flip-flops, other flip-flops and isolation latches (asicw_breakdown.txt).
cd $(dirname $0); T=$1; M=$2; H=$(pwd); TR=$(readlink -f ../traces/net_$M.txt)
LIB=$NANGATE45_LIB
. ../env.sh
S=$H/simbd_${T}_$M; mkdir -p "$S"; cd "$S" || exit 1
python3 $H/groups.py $H/nw_$T.v $S/grp > groups.out
xvlog -nolog $H/nangate_cells.v $H/nw_$T.v > xvlog.out 2>&1
xvhdl -nolog $H/../rtl/tb/macw_tb.vhd > xvhdl.out 2>&1
xelab -nolog -debug typical -generic_top "trace=$TR" -generic_top "outfile=$S/out.txt" macw_tb -s snap > xelab.out 2>&1 || { tail -3 xelab.out; exit 1; }
printf "open_saif $S/act.saif\nlog_saif [get_objects -r /macw_tb/dut/*]\nrun all\nclose_saif\nquit\n" > sim.tcl
xsim -nolog snap -tclbatch sim.tcl > xsim.out 2>&1
sed -i '/^ *([^ ]*\/[^ ]* (T0/d' act.saif
(cd $H && NET=nw_$T.v LIB=$LIB PERIOD=20 SAIF=$S/act.saif SCOPE=macw_tb/dut GRP=$S/grp $EDA_BIN/sta -no_splash -exit sta_bd.tcl > $S/power.txt 2>&1)
echo "$T $M total_W $(grep '^Total' power.txt | awk '{print $5}') $(grep '^GROUP' power.txt | awk '{printf "%s %s %s ", $2, $3, $4}')" >> $H/asicw_breakdown.txt
grep -q '^GROUP lat' power.txt && rm -rf act.saif xsim.dir snap.wdb
