#!/bin/bash
# TangramFP MAC with registered (external) mode and error correction: corr 1 (MSB) and 2 (rounding of A and C)
cd $(dirname $0); . ~/tools/Xilinx/Vivado/2018.3/settings64.sh
for v in "out_ext_msb 1" "out_ext_rte 2"; do set -- $v
  timeout 1800 vivado -mode batch -nojournal -log $1.log -source synth.tcl -tclargs $1 15 4 $2 > /dev/null 2>&1 &
done; wait
for t in syn_full syn_skip_bd syn_ac syn_skip net_resnet18 net_mobilenet_v2 net_resnet50 net_vit_b_16; do
  for v in out_ext_msb out_ext_rte; do ./run_power.sh $v traces/m_$t.txt $t mac_trace_tb_ext > $v/power_$t.log 2>&1 & done; wait
done
grep -h POWER_mW out_ext_msb/power_*.log out_ext_rte/power_*.log > power_summary_extcorr.txt
echo EXTCORR_DONE >> power_summary_extcorr.txt
