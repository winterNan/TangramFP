#!/bin/bash
# Controller-cost breakdown: hierarchy-kept builds of the standard MAC (pe_std_nf) and design vi (pe_detail),
# then post-route timing-simulation power on the four streams; hierarchical power in <dir>/power_<net>.rpt.
cd $(dirname $0); . ../env.sh
[ -f pe_std_nf/timesim.v ] || vivado -mode batch -nojournal -log pe_std_nf.log -source synth_w_nf.tcl -tclargs pe_std_nf 20 0 0 Default > /dev/null 2>&1
[ -f pe_detail/timesim.v ] || vivado -mode batch -nojournal -log pe_detail.log -source synth_w_nf.tcl -tclargs pe_detail 20 5 0 Default > /dev/null 2>&1
echo PR_DONE >> ctrl_bd.txt
for m in resnet18 mobilenet_v2 resnet50 vit_b_16; do ./pw_w.sh pe_std_nf 0 0 $m & ./pw_w.sh pe_detail 5 0 $m & done; wait
grep -E "^pe_(std_nf|detail) " fpga_power.txt >> ctrl_bd.txt
echo CTRL_DONE >> ctrl_bd.txt
