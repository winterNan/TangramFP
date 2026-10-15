#!/bin/bash
# Front end (Vivado), synthesis to Nangate45 (Yosys), static timing (OpenSTA) for one MAC variant.
# usage: run_asic.sh <tag> <gating> <corr>
cd $(dirname $0); T=$1; G=$2; C=$3
LIB=$HOME/TangramFP-jpdc/oss/nangate45/lib/NangateOpenCellLibrary_typical.lib
. ~/tools/Xilinx/Vivado/2018.3/settings64.sh
timeout 1800 vivado -mode batch -nojournal -nolog -source vfront.tcl -tclargs x_$T.v $G $C > vf_$T.log 2>&1
n=$(grep -n "ifndef GLBL" x_$T.v | head -1 | cut -d: -f1); head -n $((n-1)) x_$T.v > x_${T}_c.v
sed -e "s#OSS/share/yosys#$HOME/eda/share/yosys#; s#read_verilog NET#read_verilog x_${T}_c.v#; s#LIB#$LIB#g; s#PERIOD#2000#; s#OUT#n_$T.v#; s#LATCHMAP#$(pwd)/latch_map.v#" ysyn.ys.in > y_$T.ys
timeout 3600 ~/eda/bin/yosys -q -l y_$T.log y_$T.ys > /dev/null 2>&1
NET=n_$T.v LIB=$LIB PERIOD=10 ~/eda/bin/sta -no_splash -exit sta.tcl > s_$T.log 2>&1
echo "$T gating=$G corr=$C $(grep -o "Chip area for module .\\\\MAC.: [0-9.]*" y_$T.log | grep -o "[0-9.]*$") um2 cells=$(grep -B1 "Chip area" y_$T.log | grep -o "^ *[0-9]*" | head -1 | tr -d " ") latches=$(grep -c "DLH_X\|DLL_X" n_$T.v) unmapped=$(grep -c "DLATCH" n_$T.v) arrival=$(grep -m1 "data arrival time" s_$T.log | awk "{print \$1}") ns slack=$(grep -m1 "slack" s_$T.log | awk "{print \$1}") power_vectorless=$(grep "^Total" s_$T.log | awk "{print \$5}")"
