#!/bin/bash
# Complete-MAC variant through the standard-cell flow: front end, Yosys to Nangate45, OpenSTA timing.
# usage: run_asic_w.sh <tag> <tangram> <corr>
cd $(dirname $0); T=$1; G=$2; C=$3
LIB=$NANGATE45_LIB
. ../env.sh
timeout 1800 vivado -mode batch -nojournal -nolog -source vfront_w.tcl -tclargs xw_$T.v $G $C > vfw_$T.log 2>&1
n=$(grep -n "ifndef GLBL" xw_$T.v | head -1 | cut -d: -f1); head -n $((n-1)) xw_$T.v > xw_${T}_c.v
sed -e "s#OSS/share/yosys#$YOSYS_SHARE#; s#read_verilog NET#read_verilog xw_${T}_c.v#; s#hierarchy -top MAC#hierarchy -top MACW#; s#synth -top MAC #synth -top MACW #; s#LIB#$LIB#g; s#PERIOD#2000#; s#OUT#nw_$T.v#; s#LATCHMAP#$(pwd)/latch_map.v#" ysyn.ys.in > yw_$T.ys
timeout 3600 $EDA_BIN/yosys -q -l yw_$T.log yw_$T.ys > /dev/null 2>&1
NET=nw_$T.v LIB=$LIB PERIOD=10 $EDA_BIN/sta -no_splash -exit sta_w.tcl > sw_$T.log 2>&1
NET=nw_$T.v LIB=$LIB PERIOD=10 LATCH_TRANSPARENT=1 $EDA_BIN/sta -no_splash -exit sta_w.tcl > swl_$T.log 2>&1
echo "$T tangram=$G corr=$C area $(grep -o "Chip area for module .\\\\MACW.: [0-9.]*" yw_$T.log | grep -o "[0-9.]*$") latches $(grep -c "DLH_X" nw_$T.v) unmapped $(grep -c DLATCH nw_$T.v) reg2reg $(grep -m1 "data arrival time" sw_$T.log | awk '{print $1}') reg2reg_latch_transparent $(grep -m1 "data arrival time" swl_$T.log | awk '{print $1}') $(grep -m1 "latch enable pins" swl_$T.log)"
