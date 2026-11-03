#!/bin/bash
# Arrays with round-to-nearest-even FP16 accumulation (rtl/array): place and route all six, then power from the post-route
# functional netlist on the full-K tiles (stim/f4_*, stim/f8_*), checked cycle by cycle against the RTL simulation.
cd $(dirname $0); . ../env.sh; H=$(pwd)
pr() { [ -f $1/funcsim.v ] || timeout 21600 vivado -mode batch -nojournal -log $1.log -source synth_arr.tcl -tclargs $1 20 $2 $3 $4 ../rtl/array 1 Default > /dev/null 2>&1; }
fpow() {  # dir N tangram corr workload
  D=$H/$1; N=$2; M=$5; ST=$(readlink -f stim/g${N}_$M.txt); R=$H/out/gk_N${N}_t$3_c$4_$M.txt
  [ -f $R ] || ./run_rtl.sh $N $3 $4 stim/g${N}_$M.txt $R > /dev/null
  S=$D/fpow_gk_$M; mkdir -p "$S"; cd "$S" || return
  xvlog -nolog $D/funcsim.v $XILINX_VIVADO/data/verilog/src/glbl.v > xvlog.out 2>&1
  xvhdl -nolog $H/../rtl/tb/array_tb.vhd > xvhdl.out 2>&1
  xelab -nolog -L unisims_ver -L secureip -debug typical -generic_top "N=$N" -generic_top "trace=$ST" -generic_top "outfile=$S/out.txt" -generic_top "dump=0" array_tb glbl -s snap > xelab.out 2>&1
  printf "open_saif $S/act.saif\nlog_saif [get_objects -r /array_tb/dut/*]\nrun all\nclose_saif\nquit\n" > sim.tcl
  xsim -nolog snap -tclbatch sim.tcl > xsim.out 2>&1
  sed -E "s/\(TIMESCALE +1 ps\)/(TIMESCALE 10 fs)/" act.saif > act_x100.saif
  (cd $H && vivado -mode batch -nojournal -nolog -source ../fpga_mac/power.tcl -tclargs $D $S/act_x100.saif gk_$M array_tb > $S/power.out 2>&1)
  p=$(awk '/^\| sarray /{print $4*10; exit}' $D/power_gk_$M.rpt)
  x=$(paste -d" " <(cut -d" " -f1 out.txt) <(cut -d" " -f1 $R) | awk '{if ($1!=$2) x++} END {print x+0}')
  echo "$1 gk_$M power_mW $p mismatch $x of $(wc -l < out.txt)" >> $H/arrays_power.txt
  rm -rf act.saif act_x100.saif xsim.dir snap.wdb; cd $H
}
# stimuli with layers sampled in proportion to their number of dot products (MACs / K); P&R is reused
for m in resnet18 mobilenet_v2 resnet50 vit_b_16; do
  [ -f stim/g4_$m.txt ] || python3 gentile.py $m 4 48 100000 stim/g4_$m.txt stim/g4_$m.npz dp >> arrays_power.txt 2>&1
  [ -f stim/g8_$m.txt ] || python3 gentile.py $m 8 36 100000 stim/g8_$m.txt stim/g8_$m.npz dp >> arrays_power.txt 2>&1
done
echo STIM_DONE >> arrays_power.txt
for m in resnet18 mobilenet_v2 resnet50 vit_b_16; do fpow r4_std 4 0 0 $m & fpow r4_sync 4 2 0 $m & fpow r4_syncrte 4 2 2 $m & done; wait
echo RNE4_DONE >> arrays_power.txt
for m in resnet18 mobilenet_v2 resnet50 vit_b_16; do fpow r8_std 8 0 0 $m & fpow r8_sync 8 2 0 $m & fpow r8_syncrte 8 2 2 $m & done; wait
echo RNE8_DONE >> arrays_power.txt
