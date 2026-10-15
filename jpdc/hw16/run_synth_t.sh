#!/bin/bash
# Timing view of the MAC variants.  usage: run_synth_t.sh <period_ns>...
. ~/tools/Xilinx/Vivado/2018.3/settings64.sh
for P in "$@"; do
for v in ${VARIANTS:-"std 0 0" "sel 1 0" "sel_msb 1 1" "sel_rte 1 2" "reg 3 0" "reg_msb 3 1" "reg_rte 3 2"}; do
  set -- $v
  timeout 900 vivado -mode batch -nojournal -log t_$1_p$P.log -source synth_t.tcl -tclargs t_$1_p$P $P $2 $3 > /dev/null 2>&1 &
done
done
wait
for d in t_*_p*/; do echo "== $d"; cat $d/summary.txt; done; grep -c "^ERROR" t_*.log
