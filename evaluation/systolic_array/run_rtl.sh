#!/bin/bash
# usage: run_rtl.sh <N> <tangram> <corr> <stim> <out>   -- functional RTL simulation with all running sums dumped
. "$(dirname "$(readlink -f "$0")")/../env.sh"
N=$1; TG=$2; CR=$3; ST=$(readlink -f $4); OUT=$(readlink -f $5); HERE=$(dirname $(readlink -f $0))
S=$HERE/out/rtl_${N}_${TG}_${CR}_$$; mkdir -p $S; cd $S
xvhdl -nolog $HERE/../rtl/array/tools.vhd $HERE/../rtl/array/LZC.vhd $HERE/../rtl/array/CSA2i.vhd $HERE/../rtl/array/csa_4i.vhd $HERE/../rtl/array/DaddaMultiplier.vhd $HERE/../rtl/array/fp_add.vhd $HERE/../rtl/array/kacy_mult.vhd $HERE/../rtl/array/mode_sel.vhd $HERE/../rtl/array/MAC.vhd $HERE/../rtl/array/pe.vhd $HERE/../rtl/array/sarray.vhd $HERE/../rtl/tb/array_tb_rtl.vhd > xvhdl.out 2>&1 || { tail -20 xvhdl.out; exit 1; }
xelab -nolog -generic_top "N=$N" -generic_top "tangram=$TG" -generic_top "corr=$CR" -generic_top "trace=$ST" -generic_top "outfile=$OUT" -generic_top "dump=1" array_tb_rtl -s snap > xelab.out 2>&1 || { tail -20 xelab.out; exit 1; }
xsim -nolog snap -R > xsim.out 2>&1; tail -3 xsim.out; cd $HERE; rm -rf $S
