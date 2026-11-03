# Creates one Vivado GUI project per evaluated design (Kintex-7 xc7k160tffg676-2).
#   cd evaluation/vivado_projects && vivado -mode batch -source make_projects.tcl            (all projects)
#   cd evaluation/vivado_projects && vivado -mode batch -source make_projects.tcl -tclargs mac_vi_reg_ce
# Then open e.g. proj/mac_vi_reg_ce/mac_vi_reg_ce.xpr in the GUI.
# Settings follow the batch flows (fpga_mac/synth_w.tcl, fpnew/synth_fpnew_w.tcl, systolic_array/synth_arr.tcl): out-of-context
# synthesis with hierarchy rebuilt, 20 ns clock, Default placement, phys_opt, route.
set G [file normalize [file dirname [info script]]]
set E [file dirname $G]
set part xc7k160tffg676-2
set MAC_SRC {tools LZC CSA2i csa_4i DaddaMultiplier fp_add kacy_mult mode_sel MAC macw}
set ARR_SRC [concat $MAC_SRC sarray]
set FPN {fpnew_pkg.sv common_cells/src/cf_math_pkg.sv common_cells/src/lzc.sv fpnew_classifier.sv fpnew_rounding.sv fpnew_fma.sv}

# name  kind  generics  sim-trace  description
set designs {
  mac_i_std            mac {tangram=0 corr=0} {}  "Table 7 i: standard MAC"
  mac_ii_inmac         mac {tangram=3 corr=0} {}  "Table 7 ii: in-MAC (same-cycle) mode, no isolation"
  mac_iii_inmac_latch  mac {tangram=4 corr=0} {}  "Table 7 iii: in-MAC mode, isolation latches"
  mac_iv_reg           mac {tangram=2 corr=0} {}  "Table 7 iv: registered mode, no isolation"
  mac_v_reg_latch      mac {tangram=1 corr=0} {}  "Table 7 v: registered mode, isolation latches"
  mac_v_reg_latch_msb  mac {tangram=1 corr=1} {}  "Table 8: v+MSB"
  mac_v_reg_latch_ro   mac {tangram=1 corr=2} {}  "Table 8: v+Ro"
  mac_vi_reg_ce        mac {tangram=5 corr=0} {}  "Table 7 vi: registered mode, clock-enable isolation"
  mac_vi_reg_ce_msb    mac {tangram=5 corr=1} {}  "Table 7: vi+MSB"
  mac_vi_reg_ce_ro     mac {tangram=5 corr=2} {}  "Table 7: vi+Ro"
  mac_fpnew            fpnew {INREG=1} {}         "Table 7: FPnew FP16 FMA with the same input registers"
  arr4_std             arr {N=4 tangram=0 corr=0 use_bufg=1} {} "4x4 systolic array, standard PEs"
  arr4_tfp             arr {N=4 tangram=2 corr=0 use_bufg=1} {} "4x4 TangramFP array (vi): registered mode, clock enables"
  arr4_tfp_rte         arr {N=4 tangram=2 corr=2 use_bufg=1} {} "4x4 TangramFP array with rounding"
  arr8_std             arr {N=8 tangram=0 corr=0 use_bufg=1} {} "8x8 systolic array, standard PEs"
  arr8_tfp             arr {N=8 tangram=2 corr=0 use_bufg=1} {} "8x8 TangramFP array, registered mode, clock enables"
  arr8_tfp_rte         arr {N=8 tangram=2 corr=2 use_bufg=1} {} "8x8 TangramFP array with rounding"
}

proc pre {p l s} { set r {}; foreach f $l { lappend r $p$f$s }; return $r }
proc gval {gens key} { foreach g $gens { lassign [split $g =] k v; if {$k eq $key} { return $v } }; return 0 }

set only [expr {$argc > 0 ? $argv : {}}]
foreach {name kind gens _ desc} $designs {
  if {[llength $only] && [lsearch -exact $only $name] < 0} continue
  puts "== $name: $desc"
  create_project -force $name $G/proj/$name -part $part
  set_property target_language VHDL [current_project]
  switch $kind {
    mac   { add_files -norecurse [pre $E/rtl/mac/ $MAC_SRC .vhd]; set top MACW }
    arr   { # array sources (rtl/array: FP16 running sum rounded to nearest even)
            add_files -norecurse [pre $E/rtl/array/ [concat $ARR_SRC pe] .vhd]
            set top sarray }
    fpnew { add_files -norecurse [concat [pre $E/fpnew/cvfpu/src/ $FPN {}] $E/fpnew/fpnew_macw.sv]
            set_property include_dirs $E/fpnew/cvfpu/src/common_cells/include [get_filesets sources_1]
            # Vivado's automatic ordering drops the FPnew cores from simulation; compile in the listed order.
            set_property source_mgmt_mode DisplayOnly [current_project]
            set top MACW }
  }
  set_property top $top [get_filesets sources_1]
  set_property generic $gens [get_filesets sources_1]
  set xdc [add_files -fileset constrs_1 -norecurse $G/xdc/[expr {$kind eq "arr" ? "arr.xdc" : "mac.xdc"}]]
  # The batch flows create the clock after synth_design, so synthesis there is unconstrained.
  set_property used_in_synthesis false $xdc

  set more "-mode out_of_context"
  if {$kind eq "fpnew"} { append more " -max_dsp 0" }
  set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value $more -objects [get_runs synth_1]
  set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]
  set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Default [get_runs impl_1]
  set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]

  # Behavioural simulation on the ResNet18 stream (change the trace generic for the other networks).
  switch $kind {
    mac   { add_files -fileset sim_1 -norecurse $G/tb/macw_tb_gui.vhd; set tb macw_tb_gui
            set sg [list tangram=[gval $gens tangram] corr=[gval $gens corr] trace=$E/traces/net_resnet18.txt outfile=$G/proj/$name/out_resnet18.txt] }
    fpnew { add_files -fileset sim_1 -norecurse $E/rtl/tb/macw_tb.vhd; set tb macw_tb
            set sg [list trace=$E/traces/net_resnet18.txt outfile=$G/proj/$name/out_resnet18.txt] }
    arr   { add_files -fileset sim_1 -norecurse $G/tb/array_tb_gui.vhd; set tb array_tb_gui
            set n [gval $gens N]
            set sg [list N=$n tangram=[gval $gens tangram] corr=[gval $gens corr] trace=$E/systolic_array/stim/g${n}_resnet18.txt outfile=$G/proj/$name/out_resnet18.txt] }
  }
  set_property top $tb [get_filesets sim_1]
  set_property generic $sg [get_filesets sim_1]
  set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
  close_project
}
