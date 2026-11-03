#!/bin/bash
# RTL simulation of MACW (rtl/mac) on a trace.  usage: rtl_macw.sh <tangram> <corr> <trace> <out>
. "$(dirname "$(readlink -f "$0")")/../env.sh"
T=$1; C=$2; TR=$(readlink -f $3); OUT=$(readlink -f $4); H=$EVAL; S=$(mktemp -d -p $H/fpga_mac); cd $S
xvhdl -nolog $H/rtl/mac/{tools,LZC,CSA2i,csa_4i,DaddaMultiplier,fp_add,kacy_mult,mode_sel,MAC,macw}.vhd > x.out 2>&1 || { tail -5 x.out; exit 1; }
sed "s/dut *: *MACW port map/dut : entity work.MACW generic map (tangram => $T, corr => $C) port map/" $H/rtl/tb/macw_tb.vhd > tb.vhd; xvhdl -nolog tb.vhd >> x.out 2>&1
xelab -nolog -generic_top "trace=$TR" -generic_top "outfile=$OUT" macw_tb -s snap > e.out 2>&1 || { tail -5 e.out; exit 1; }
xsim -nolog snap -R > s.out 2>&1; cd ..; rm -rf $S
