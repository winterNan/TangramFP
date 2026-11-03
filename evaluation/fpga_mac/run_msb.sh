#!/bin/bash
# Table 7 MSB row: design vi (registered mode, clock enables) with MSB correction (tangram=5, corr=1),
# Default and ExtraNetDelay_high placements, post-route timing-simulation power on the four streams.
cd $(dirname $0); . ../env.sh
for b in syncmsb:Default syncmsb2:ExtraNetDelay_high; do IFS=: read d p <<< "$b"
  timeout 3600 vivado -mode batch -nojournal -log f_$d.log -source synth_w.tcl -tclargs f_$d 20 5 1 $p > /dev/null 2>&1 & done; wait
for d in syncmsb syncmsb2; do echo "f_$d $(tr "\n" " " < f_$d/summary.txt)" >> msb_mac.txt; done
for d in syncmsb syncmsb2; do for m in resnet18 mobilenet_v2 resnet50 vit_b_16; do ./pw_w.sh f_$d 5 1 $m & done; done; wait
grep -E "^f_syncmsb2? " fpga_power.txt >> msb_mac.txt; echo MSBMAC_DONE >> msb_mac.txt
