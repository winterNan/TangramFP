#!/bin/bash
cd $(dirname $0)
for m in resnet18 mobilenet_v2 resnet50 vit_b_16; do
  for v in nolatch:1:0 tfp:2:0 tfp_msb:2:1 tfp_rte:2:2; do IFS=: read t g c <<< "$v"
    ( [ -f rtl_g${g}_c${c}_$m.txt ] || ./rtl_mac.sh $g $c ../hw16/traces/m_net_$m.txt rtl_g${g}_c${c}_$m.txt
      r=$(./run_pw.sh $t mac_trace_tb_ext ../hw16/traces/m_net_$m.txt $m)
      x=$(paste -d" " sim_${t}_$m/out.txt rtl_g${g}_c${c}_$m.txt | awk "{n++; if (\$1!=\$3 || \$2!=\$4) {x++; last=n}} END {print x+0, \"last\", last+0}")
      echo "$r mismatch $x" >> asic_power2.txt ) &
  done; wait
done
echo INMAC_DONE >> asic_power2.txt
