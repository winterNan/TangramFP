#!/bin/bash
# RTL simulation of the latch-free MAC (arr/src2) on a trace with the external-mode testbench.  usage: rtl_mac.sh <gating> <corr> <trace> <out>
. ~/tools/Xilinx/Vivado/2018.3/settings64.sh
G=$1; C=$2; TR=$(readlink -f $3); OUT=$(readlink -f $4); H=$HOME/TangramFP-jpdc; S=$(mktemp -d -p $H/asic); cd $S
xvhdl -nolog $H/arr/src2/tools.vhd $H/arr/src2/LZC.vhd $H/arr/src2/CSA2i.vhd $H/arr/src2/csa_4i.vhd $H/arr/src2/DaddaMultiplier.vhd $H/arr/src2/fp_add.vhd $H/arr/src2/kacy_mult.vhd $H/arr/src2/mode_sel.vhd $H/arr/src2/MAC.vhd > x.out 2>&1
sed "s/dut *: *MAC port map/dut : entity work.MAC generic map (gating => $G, corr => $C) port map/" $H/hw16/tb/mac_trace_tb_ext.vhd > tb.vhd; xvhdl -nolog tb.vhd >> x.out 2>&1
xelab -nolog -generic_top "trace=$TR" -generic_top "outfile=$OUT" mac_trace_tb_ext -s snap > e.out 2>&1 && xsim -nolog snap -R > s.out 2>&1; cd ..; rm -rf $S
