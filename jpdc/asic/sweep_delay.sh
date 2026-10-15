#!/bin/bash
# Re-synthesize the latch-free variants at several ABC delay targets; report the best critical path per variant.
cd $(dirname $0); LIB=$HOME/TangramFP-jpdc/oss/nangate45/lib/NangateOpenCellLibrary_typical.lib
one() {  # tag target_ps
  sed -e "s#OSS/share/yosys#$HOME/eda/share/yosys#; s#read_verilog NET#read_verilog x_${1}_c.v#; s#LIB#$LIB#g; s#PERIOD#$2#; s#OUT#d_${1}_$2.v#; s#LATCHMAP#$(pwd)/latch_map.v#" ysyn.ys.in > yd_${1}_$2.ys
  ~/eda/bin/yosys -q -l yd_${1}_$2.log yd_${1}_$2.ys > /dev/null 2>&1
  NET=d_${1}_$2.v LIB=$LIB PERIOD=10 ~/eda/bin/sta -no_splash -exit sta.tcl > sd_${1}_$2.log 2>&1
  echo "$1 target_ps $2 area $(grep -o "Chip area for module .\\\\MAC.: [0-9.]*" yd_${1}_$2.log | grep -o "[0-9.]*$") arrival $(grep -m1 "data arrival time" sd_${1}_$2.log | awk "{print \$1}")" >> sweep.txt
}
for t in std nolatch extnl extnl_rte; do for d in 1000 1500 2500 3000 4000; do one $t $d & done; wait; done
echo SWEEP_DONE >> sweep.txt
