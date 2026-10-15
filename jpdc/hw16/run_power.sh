#!/bin/bash
# usage: run_power.sh <variant_outdir> <trace.txt> <tag>   -- timing simulation with SDF, SAIF, report_power
. ~/tools/Xilinx/Vivado/2018.3/settings64.sh
D=$(readlink -f $1); T=$(readlink -f $2); TAG=$3; TB=${4:-mac_trace_tb}; HERE=$(dirname $(readlink -f $0))
S=$D/sim_$TAG; rm -rf $S; mkdir -p $S; cd $S
xvlog -nolog $D/timesim.v $XILINX_VIVADO/data/verilog/src/glbl.v > xvlog.out 2>&1
xvhdl -nolog $HERE/tb/$TB.vhd > xvhdl.out 2>&1
xelab -nolog -L simprims_ver -L secureip -debug typical -sdfmax /$TB/dut=$D/timesim.sdf \
      -generic_top "trace=$T" -generic_top "outfile=$S/out.txt" $TB glbl -s snap > xelab.out 2>&1
cat > sim.tcl <<EOT
open_saif $S/act.saif
log_saif [get_objects -r /$TB/dut/*]
run all
close_saif
quit
EOT
xsim -nolog snap -tclbatch sim.tcl > xsim.out 2>&1
# report_power prints 3 decimals of a watt: scale the toggle rates by 100 (10 fs time unit) and read the result as 10 mW units
sed -E "s/\(TIMESCALE +1 ps\)/(TIMESCALE 10 fs)/" $S/act.saif > $S/act_x100.saif
cd $HERE && vivado -mode batch -nojournal -nolog -source power.tcl -tclargs $D $S/act_x100.saif $TAG $TB > $S/power.out 2>&1
python3 - $D/power_$TAG.rpt <<'PY'
import sys, re
vals = {}
for l in open(sys.argv[1]):
    m = re.match(r"\|\s+(MAC|fp_add|kacy|msel|MUL_ac|MUL_ad|MUL_bc|MUL_bd)\s+\|\s+([<0-9.]+)", l)
    if m and m.group(1) not in vals: vals[m.group(1)] = float(m.group(2).lstrip("<")) * 10
print("POWER_mW", sys.argv[1], " ".join(f"{k}={v:.2f}" for k, v in vals.items()))
PY
