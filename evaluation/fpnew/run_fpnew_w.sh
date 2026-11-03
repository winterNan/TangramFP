#!/bin/bash
# FPnew FMA with (in1) and without (in0) input registers, two placements each, in the Table 7 flow.
cd $(dirname $0); . ../env.sh
B="w_in1:1:Default w_in1x:1:ExtraNetDelay_high w_in0:0:Default w_in0x:0:ExtraNetDelay_high"
for b in $B; do IFS=: read d r p <<< "$b"
  timeout 3600 vivado -mode batch -nojournal -log $d.log -source synth_fpnew_w.tcl -tclargs $d 20 $r $p > /dev/null 2>&1 &
done; wait
rm -f fpnew_w_power.txt
for b in $B; do IFS=: read d r p <<< "$b"; for m in resnet18 mobilenet_v2 resnet50 vit_b_16; do
  ./pw_fpnew_w.sh $d $m &
done; wait; done
for b in $B; do IFS=: read d r p <<< "$b"; echo "$d $(tr '\n' ' ' < $d/summary.txt) $(grep -E 'Slice LUTs' $d/util.rpt | head -1)"; done > fpnew_w_summary.txt
echo FPNEW_W_DONE >> fpnew_w_power.txt
