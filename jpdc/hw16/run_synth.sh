#!/bin/bash
# Place and route the five MAC variants for the power runs.
. ~/tools/Xilinx/Vivado/2018.3/settings64.sh
for v in "std 0 0" "nolatch 1 0" "tangram 2 0" "tangram_msb 2 1" "tangram_rte 2 2"; do
  set -- $v
  timeout 900 vivado -mode batch -nojournal -log out_$1.log -source synth.tcl -tclargs out_$1 15 $2 $3 > /dev/null 2>&1 &
done
wait
for d in std nolatch tangram tangram_msb tangram_rte; do echo "== $d"; cat out_$d/summary.txt; done; grep -c "^ERROR" out_*.log
