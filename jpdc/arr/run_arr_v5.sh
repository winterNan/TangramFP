#!/bin/bash
# Arrays with the latch-free adder (src2). tangram: 0 standard, 2 TangramFP with synchronous (clock-enable) isolation,
# 3 TangramFP without isolation; corr 2 (rounding). Every power run is checked cycle by cycle against RTL.
cd $(dirname $0); . ~/tools/Xilinx/Vivado/2018.3/settings64.sh
pr() { [ -f $1/timesim.sdf ] || timeout 7200 vivado -mode batch -nojournal -log $1.log -source synth_arr.tcl -tclargs $1 20 $2 $3 $4 src2 1 $5 > /dev/null 2>&1; }
meas() {  # dir N tangram corr
  for m in resnet18 mobilenet_v2 resnet50 vit_b_16; do
    [ -f out/z_N$2_t$3_c$4_$m.txt ] || SRC=src2 ./run_rtl.sh $2 $3 $4 stim/s$2_$m.txt out/z_N$2_t$3_c$4_$m.txt > /dev/null
    ./run_power_arr.sh $1 $2 stim/s$2_$m.txt $m > $1/power_$m.log 2>&1
    x=$(paste -d" " <(cut -d" " -f1 $1/sim_$m/out.txt) <(cut -d" " -f1 out/z_N$2_t$3_c$4_$m.txt) | awk "{if (\$1!=\$2) x++} END {print x+0}")
    p=$(awk "/^\| sarray /{print \$4*10; exit}" $1/power_$m.rpt)
    echo "$1 $m power_mW $p mismatch_cycles $x" >> v5_results.txt
  done
}
pr w4_std 4 0 0 Default & pr w4_sync 4 2 2 Default & pr w4_nolat 4 3 2 Default & pr x4_std 4 0 0 ExtraNetDelay_high & pr x4_sync 4 2 2 ExtraNetDelay_high & wait
meas w4_std 4 0 0 & meas w4_sync 4 2 2 & meas w4_nolat 4 3 2 & wait
meas x4_std 4 0 0 & meas x4_sync 4 2 2 & pr w8_std 8 0 0 Default & pr w8_sync 8 2 2 Default & wait
meas w8_std 8 0 0 & meas w8_sync 8 2 2 & wait
for d in w4_std w4_sync w4_nolat x4_std x4_sync w8_std w8_sync; do echo "== $d"; cat $d/summary.txt; done >> v5_results.txt
echo V5_DONE >> v5_results.txt
