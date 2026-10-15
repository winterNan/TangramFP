#!/bin/bash
# Synthesis of all variants (latches mapped), then gate-level power on four DNN traces, checked against RTL.
cd $(dirname $0)
V="std:0:0 nolatch:1:0 tfp:2:0 tfp_msb:2:1 tfp_rte:2:2 ext:4:0 ext_msb:4:1 ext_rte:4:2 extnl:5:0 extnl_rte:5:2"
for v in $V; do IFS=: read t g c <<< "$v"; ./run_asic.sh $t $g $c > r_$t.txt & done; wait
cat r_*.txt > asic_summary.txt
for m in resnet18 mobilenet_v2 resnet50 vit_b_16; do
  for v in $V; do IFS=: read t g c <<< "$v"
    ( [ -f rtl_g${g}_c${c}_$m.txt ] || ./rtl_mac.sh $g $c ../hw16/traces/m_net_$m.txt rtl_g${g}_c${c}_$m.txt
      r=$(./run_pw.sh $t mac_trace_tb_ext ../hw16/traces/m_net_$m.txt $m)
      x=$(paste -d" " sim_${t}_$m/out.txt rtl_g${g}_c${c}_$m.txt | awk "{if (\$1!=\$3 || \$2!=\$4) x++} END {print x+0}")
      echo "$r mismatch $x" >> asic_power.txt ) &
  done; wait
done
echo ASIC2_DONE >> asic_power.txt
