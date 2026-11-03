#!/bin/bash
# Mode-generation breakdown: design vi with the mode generation in its own entity (rtl/mac_breakdown), then
# post-route timing-simulation power on the four streams.
cd $(dirname $0); . ../env.sh
vivado -mode batch -nojournal -log pe_bd.log -source synth_w_bd.tcl -tclargs pe_bd 20 5 0 Default > /dev/null 2>&1
echo PR2_DONE >> ctrl_bd.txt
for m in resnet18 mobilenet_v2 resnet50 vit_b_16; do ./pw_w.sh pe_bd 5 0 $m & done; wait
grep -E "^pe_bd " fpga_power.txt >> ctrl_bd.txt; echo CTRL2_DONE >> ctrl_bd.txt
