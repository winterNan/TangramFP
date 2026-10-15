#!/bin/bash
# RTL simulation of one MAC variant on a trace, compared with the existing post-route timing simulation output.
# usage: verify_mac.sh <outdir> <gating> <corr> <tb> <trace> <tag>
. ~/tools/Xilinx/Vivado/2018.3/settings64.sh
D=$1; G=$2; CR=$3; TB=$4; T=$(readlink -f $5); TAG=$6; HERE=$(dirname $(readlink -f $0))
S=$HERE/vrtl_${D}_$TAG; rm -rf $S; mkdir -p $S; cd $S
xvhdl -nolog $HERE/src/tools.vhd $HERE/src/LZC.vhd $HERE/src/CSA2i.vhd $HERE/src/csa_4i.vhd $HERE/src/DaddaMultiplier.vhd $HERE/src/fp_add.vhd $HERE/src/kacy_mult.vhd $HERE/src/mode_sel.vhd $HERE/src/MAC.vhd > xv.out 2>&1
sed "s/dut *: *MAC port map/dut : entity work.MAC generic map (gating => $G, corr => $CR) port map/" $HERE/tb/$TB.vhd > tb_rtl.vhd
xvhdl -nolog tb_rtl.vhd >> xv.out 2>&1
xelab -nolog -generic_top "trace=$T" -generic_top "outfile=$S/out.txt" $TB -s snap > xe.out 2>&1 || tail -5 xe.out
xsim -nolog snap -R > xs.out 2>&1
paste -d" " $HERE/$D/sim_$TAG/out.txt $S/out.txt | awk -v d=$D -v t=$TAG "{n++; if (\$1!=\$3 || \$2!=\$4) x++} END {print d, t, \"lines\", n, \"differ\", x+0}"
