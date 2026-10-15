#!/bin/bash
cd $(dirname $0)
for v in f_dsp0_p14 f_dsp1_p14; do
  for t in syn_full syn_skip_bd syn_ac syn_skip net_resnet18 net_mobilenet_v2 net_resnet50 net_vit_b_16; do
    ./run_power.sh ../fpnew/$v traces/$t.txt $t > ../fpnew/$v/power_$t.log 2>&1 &
  done
  wait
done
grep -h POWER_mW ../fpnew/f_*/power_*.log > power_summary_fpnew.txt
