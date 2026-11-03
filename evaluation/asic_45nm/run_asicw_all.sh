#!/bin/bash
cd $(dirname $0)
V="w_std:0:0 w_inmacnl:3:0 w_inmac:4:0 w_reg:1:0 w_regmsb:1:1 w_regrte:1:2 w_regnl:2:0 w_regnlrte:2:2 w_sync:5:0 w_syncrte:5:2"
for v in $V; do IFS=: read t g c <<< "$v"; [ -f nw_$t.v ] && [ $t != w_reg ] && continue; ./run_asic_w.sh $t $g $c > rw_$t.txt & done; wait
cat rw_*.txt > asicw_summary.txt
for m in resnet18 mobilenet_v2 resnet50 vit_b_16; do for v in $V; do IFS=: read t g c <<< "$v"; ./run_pw_w.sh $t $g $c $m & done; wait; done
echo ASICW_DONE >> asicw_power.txt
