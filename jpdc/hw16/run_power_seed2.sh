#!/bin/bash
# Second implementation of std / nolatch / tangram (12 ns target instead of 15 ns) to gauge place-and-route noise in the power numbers
cd $(dirname $0); . ~/tools/Xilinx/Vivado/2018.3/settings64.sh
for v in "std 0" "nolatch 1" "tangram 2"; do set -- $v
  timeout 900 vivado -mode batch -nojournal -log out2_$1.log -source synth.tcl -tclargs out2_$1 12 $2 0 > /dev/null 2>&1 &
done; wait
for t in syn_full syn_ac net_resnet18 net_mobilenet_v2 net_resnet50 net_vit_b_16; do
  for v in std nolatch tangram; do ./run_power.sh out2_$v traces/$t.txt $t > out2_$v/power_$t.log 2>&1 & done; wait
done
grep -h POWER_mW out2_*/power_*.log > power_summary_seed2.txt
