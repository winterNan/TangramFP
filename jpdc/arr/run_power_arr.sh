#!/bin/bash
# usage: run_power_arr.sh <variant_dir> <N> <stim> <tag>  -- post-route timing simulation with SDF, SAIF, report_power
. ~/tools/Xilinx/Vivado/2018.3/settings64.sh
D=$(readlink -f $1); N=$2; T=$(readlink -f $3); TAG=$4; HERE=$(dirname $(readlink -f $0))
S=$D/sim_$TAG; rm -rf $S; mkdir -p $S; cd $S
xvlog -nolog $D/timesim.v $XILINX_VIVADO/data/verilog/src/glbl.v > xvlog.out 2>&1
xvhdl -nolog $HERE/tb/array_tb.vhd > xvhdl.out 2>&1
xelab -nolog ${XELAB_EXTRA} -L simprims_ver -L secureip -debug typical -sdfmax /array_tb/dut=$D/timesim.sdf \
      -generic_top "N=$N" -generic_top "trace=$T" -generic_top "outfile=$S/out.txt" -generic_top "dump=${DUMP:-0}" -generic_top "half_ns=${HALF:-10}" array_tb glbl -s snap > xelab.out 2>&1
cat > sim.tcl <<EOT
open_saif $S/act.saif
log_saif [get_objects -r /array_tb/dut/*]
run all
close_saif
quit
EOT
xsim -nolog snap -tclbatch sim.tcl > xsim.out 2>&1
sed -E "s/\(TIMESCALE +1 ps\)/(TIMESCALE 10 fs)/" $S/act.saif > $S/act_x100.saif
cd $HERE && vivado -mode batch -nojournal -nolog -source ../hw16/power.tcl -tclargs $D $S/act_x100.saif $TAG array_tb > $S/power.out 2>&1
rm -f $S/act.saif $S/act_x100.saif
