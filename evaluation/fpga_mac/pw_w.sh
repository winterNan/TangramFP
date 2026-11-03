#!/bin/bash
# Post-route timing simulation of a MACW netlist on a trace, SAIF, report_power; check against RTL.
# usage: pw_w.sh <dir> <tangram> <corr> <workload>
. "$(dirname "$(readlink -f "$0")")/../env.sh"
D=$(readlink -f $1); T=$2; C=$3; M=$4; H=$(pwd); TR=$(readlink -f ../traces/net_$M.txt)
[ -f rtl_t${T}_c${C}_$M.txt ] || ./rtl_macw.sh $T $C $TR rtl_t${T}_c${C}_$M.txt
S=$D/sim_$M; mkdir -p "$S"; cd "$S" || exit 1
xvlog -nolog $D/timesim.v $XILINX_VIVADO/data/verilog/src/glbl.v > xvlog.out 2>&1
xvhdl -nolog $H/../rtl/tb/macw_tb.vhd > xvhdl.out 2>&1
xelab -nolog -L simprims_ver -L secureip -debug typical -sdfmax /macw_tb/dut=$D/timesim.sdf -generic_top "trace=$TR" -generic_top "outfile=$S/out.txt" macw_tb glbl -s snap > xelab.out 2>&1
printf "open_saif $S/act.saif\nlog_saif [get_objects -r /macw_tb/dut/*]\nrun all\nclose_saif\nquit\n" > sim.tcl
xsim -nolog snap -tclbatch sim.tcl > xsim.out 2>&1
sed -E "s/\(TIMESCALE +1 ps\)/(TIMESCALE 10 fs)/" act.saif > act_x100.saif
(cd $H && vivado -mode batch -nojournal -nolog -source power.tcl -tclargs $D $S/act_x100.saif $M macw_tb > $S/power.out 2>&1)
p=$(awk '/^\| MACW /{print $4*10; exit}' $D/power_$M.rpt); mac=$(awk '/^\|   mac_i /{print $4*10; exit}' $D/power_$M.rpt)
x=$(paste -d" " out.txt $H/rtl_t${T}_c${C}_$M.txt | awk '{if ($1!=$3 || $2!=$4) x++} END {print x+0}')
echo "$(basename $D) $M total_mW $p mac_i_mW $mac mismatch $x" >> $H/fpga_power.txt
rm -rf act.saif act_x100.saif xsim.dir snap.wdb
