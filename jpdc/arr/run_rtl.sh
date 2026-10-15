#!/bin/bash
# usage: run_rtl.sh <N> <tangram> <corr> <stim> <out>   -- functional RTL simulation with all running sums dumped
. ~/tools/Xilinx/Vivado/2018.3/settings64.sh
N=$1; TG=$2; CR=$3; ST=$(readlink -f $4); OUT=$(readlink -f $5); HERE=$(dirname $(readlink -f $0))
S=$HERE/out/rtl_${N}_${TG}_${CR}_$$; mkdir -p $S; cd $S
xvhdl -nolog $HERE/${SRC:-src}/tools.vhd $HERE/${SRC:-src}/LZC.vhd $HERE/${SRC:-src}/CSA2i.vhd $HERE/${SRC:-src}/csa_4i.vhd $HERE/${SRC:-src}/DaddaMultiplier.vhd $HERE/${SRC:-src}/fp_add.vhd $HERE/${SRC:-src}/kacy_mult.vhd $HERE/${SRC:-src}/mode_sel.vhd $HERE/${SRC:-src}/MAC.vhd $HERE/${SRC:-src}/pe.vhd $HERE/${SRC:-src}/sarray.vhd $HERE/tb/array_tb_rtl.vhd > xvhdl.out 2>&1 || { tail -20 xvhdl.out; exit 1; }
xelab -nolog -generic_top "N=$N" -generic_top "tangram=$TG" -generic_top "corr=$CR" -generic_top "trace=$ST" -generic_top "outfile=$OUT" -generic_top "dump=1" array_tb_rtl -s snap > xelab.out 2>&1 || { tail -20 xelab.out; exit 1; }
xsim -nolog snap -R > xsim.out 2>&1; tail -3 xsim.out; cd $HERE; rm -rf $S
