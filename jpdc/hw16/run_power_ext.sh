#!/bin/bash
# TangramFP MAC with the mode supplied together with the operands (gating = 4), two implementations
cd $(dirname $0); . ~/tools/Xilinx/Vivado/2018.3/settings64.sh
for t in syn_full syn_skip_bd syn_ac syn_skip net_resnet18 net_mobilenet_v2 net_resnet50 net_vit_b_16; do python3 tb/addmode.py traces/$t.txt traces/m_$t.txt; done
for v in "out_ext 15" "out2_ext 12"; do set -- $v
  timeout 900 vivado -mode batch -nojournal -log $1.log -source synth.tcl -tclargs $1 $2 4 0 > /dev/null 2>&1 &
done; wait
for t in syn_full syn_skip_bd syn_ac syn_skip net_resnet18 net_mobilenet_v2 net_resnet50 net_vit_b_16; do
  for v in out_ext out2_ext; do ./run_power.sh $v traces/m_$t.txt $t mac_trace_tb_ext > $v/power_$t.log 2>&1 & done; wait
done
grep -h POWER_mW out_ext/power_*.log out2_ext/power_*.log > power_summary_ext.txt
