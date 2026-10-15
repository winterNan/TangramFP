#!/bin/bash
# Power of every MAC variant on every trace (post-route timing simulation, 50 MHz).
cd $(dirname $0)
for t in syn_full syn_skip_bd syn_ac syn_skip net_resnet18 net_mobilenet_v2 net_resnet50 net_vit_b_16; do
  for v in std nolatch tangram tangram_msb tangram_rte; do
    ./run_power.sh out_$v traces/$t.txt $t > out_$v/power_$t.log 2>&1 &
  done
  wait
done
grep -h POWER_mW out_*/power_*.log > power_summary.txt
