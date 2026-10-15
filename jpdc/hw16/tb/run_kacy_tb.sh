#!/bin/bash
# usage: run_kacy_tb.sh   (from hw16/); checks kacy_mul for corr = 0, 1, 2
. ~/tools/Xilinx/Vivado/2018.3/settings64.sh
mkdir -p sim_kacy && cd sim_kacy && (cd ../tb && python3 genvec.py && mv vec?.txt ../sim_kacy/)
xvhdl -nolog ../src/tools.vhd ../src/DaddaMultiplier.vhd ../src/CSA2i.vhd ../src/csa_4i.vhd ../src/kacy_mult.vhd ../tb/kacy_tb.vhd | grep -E "ERROR|WARNING"
for c in 0 1 2; do
  xelab -nolog -generic_top corr=$c -generic_top "vecfile=vec$c.txt" kacy_tb -s kt$c 2>&1 | grep -E "ERROR"
  xsim -nolog kt$c -R 2>&1 | grep -E "KACY_TB|MISMATCH|ERROR|Failure"
done
