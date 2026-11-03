#!/bin/bash
# Post-route timing simulation of an FPnew MACW netlist on a trace (same steps as fpga_mac/pw_w.sh), SAIF, report_power.
# usage: pw_fpnew_w.sh <dir> <workload>
. "$(dirname "$(readlink -f "$0")")/../env.sh"
D=$(readlink -f $1); M=$2; H=$(pwd); TR=$(readlink -f ../traces/net_$M.txt)
S=$D/sim_$M; mkdir -p "$S"; cd "$S" || exit 1
xvlog -nolog $D/timesim.v $XILINX_VIVADO/data/verilog/src/glbl.v > xvlog.out 2>&1
xvhdl -nolog $H/../rtl/tb/macw_tb.vhd > xvhdl.out 2>&1
xelab -nolog -L simprims_ver -L secureip -debug typical -sdfmax /macw_tb/dut=$D/timesim.sdf -generic_top "trace=$TR" -generic_top "outfile=$S/out.txt" macw_tb glbl -s snap > xelab.out 2>&1
printf "open_saif $S/act.saif\nlog_saif [get_objects -r /macw_tb/dut/*]\nrun all\nclose_saif\nquit\n" > sim.tcl
xsim -nolog snap -tclbatch sim.tcl > xsim.out 2>&1
sed -E "s/\(TIMESCALE +1 ps\)/(TIMESCALE 10 fs)/" act.saif > act_x100.saif
(cd $H && vivado -mode batch -nojournal -nolog -source ../fpga_mac/power.tcl -tclargs $D $S/act_x100.saif $M macw_tb > $S/power.out 2>&1)
p=$(awk '/^\| MACW /{print $4*10; exit}' $D/power_$M.rpt)
x=$(python3 $H/chk_fma.py $TR out.txt)
echo "$(basename $D) $M total_mW $p check $x" >> $H/fpnew_w_power.txt
rm -rf act.saif act_x100.saif xsim.dir snap.wdb
