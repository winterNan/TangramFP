#!/bin/bash
cd $(dirname $0); . ../env.sh
B="std:0:0:Default std2:0:0:ExtraNetDelay_high std3:0:0:SpreadLogic_high inmacnl:3:0:Default inmac:4:0:Default reg:1:0:Default reg2:1:0:ExtraNetDelay_high reg3:1:0:SpreadLogic_high regmsb:1:1:Default regrte:1:2:Default regrte2:1:2:ExtraNetDelay_high regrte3:1:2:SpreadLogic_high regnl:2:0:Default sync:5:0:Default sync2:5:0:ExtraNetDelay_high sync3:5:0:SpreadLogic_high syncrte:5:2:Default syncrte2:5:2:ExtraNetDelay_high syncrte3:5:2:SpreadLogic_high"
n=0; for b in $B; do IFS=: read d t c p <<< "$b"
  timeout 3600 vivado -mode batch -nojournal -log f_$d.log -source synth_w.tcl -tclargs f_$d 20 $t $c $p > /dev/null 2>&1 &
  n=$((n+1)); [ $((n % 6)) = 0 ] && wait; done; wait
for b in $B; do IFS=: read d t c p <<< "$b"; echo "f_$d $(tr '\n' ' ' < f_$d/summary.txt)"; done > fpga_summary.txt
n=0; for b in $B; do IFS=: read d t c p <<< "$b"; for m in resnet18 mobilenet_v2 resnet50 vit_b_16; do
  ./pw_w.sh f_$d $t $c $m &
  n=$((n+1)); [ $((n % 8)) = 0 ] && wait; done; done; wait
echo FPGA_DONE >> fpga_power.txt
