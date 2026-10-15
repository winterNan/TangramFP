# TangramFP: experiments for the JPDC revision

This folder holds the code and the result files of the experiments added in the major revision of the
journal version of TangramFP (JPDC-D-26-00511). The original conference artefacts in `hw/` and `sw/` are
unchanged. Section and table numbers refer to the revised manuscript.

The scripts were run on a Linux machine with Vivado 2018.3 (free licence, Kintex-7 `xc7k160tffg676-2`),
Yosys 0.58, OpenSTA 2.7.0, and PyTorch 2.1 on CPU. They expect this folder to be checked out as
`~/TangramFP-jpdc` (some paths are absolute); adjust the paths if you place it elsewhere.

| Folder | What it is | Paper |
|---|---|---|
| `emu/` | Batched FP16 TangramFP emulator and the application-level experiments | Sec. 6.3.1, Table 6 |
| `results/` | JSON results of the accuracy experiments | Table 6 and text |
| `hw16/` | Stand-alone FP16 MAC on the FPGA: RTL variants, testbenches, Vivado flows, power summaries | Sec. 6.3.3 (iv), 6.3.5, Tables 8 and 10 |
| `fpnew/` | Wrapper and flow for the FPnew FP16 FMA baseline | Table 10, row v |
| `arr/` | Systolic arrays built from the MAC, driven by DNN tiles | Sec. 6.3.6 |
| `asic/` | Standard-cell flow (Nangate 45 nm): synthesis, gate-level simulation, power | Sec. 6.3.7, Table 11 |

## `emu/`: emulator and application-level validation

- `tfp16.c`: batched TangramFP FP16 dot-product emulator (group mode selection, binary32 accumulator,
  selectable AC correction: truncation, MSB correction, rounding of A and C). With the same settings it is
  bit-exact against `kacy_f16_main()` of `sw/tangram16/c_src/kacy16.c` (`test_equiv.py`, 20,000 random cases).
  Build with `make` (needs F16C and OpenMP).
- `tfp.py`: ctypes front end, and `patch_functional()`, which routes `F.conv2d`, `F.linear` and
  `F.scaled_dot_product_attention` through the emulator for the duration of a run.
- `eval_img.py` (ImageNet classifiers on Imagenette), `eval_llm.py` (GPT-2), `eval_llama.py` (Llama-2-7B,
  Meta checkpoint), `train_cifar.py` (CIFAR-10 training of a ResNet-8 and a small ViT with emulated forward
  and backward passes and dynamic loss scaling), `test_grad.py`.
- `run_queue*.sh`: the exact runs of the paper. The Imagenette images, the WikiText-2 data, and the model
  weights are not included.

## `results/`

`img2_*` (1000/300 images), `img_g8_*` (threshold study), `llm_g8_*` (GPT-2 Large), `llama_g8_*` (Llama-2-7B,
Null threshold 11/12/13/disabled), `train8_g8_*` (8-epoch training). `thr1` is the Skip-BD/AC threshold,
`thr2` the Null threshold (Null for s >= thr2).

## `hw16/`: single FP16 MAC on the FPGA

- `src/`: MAC RTL with generics `gating` (0 standard, 1 mode in MAC without isolation latches, 2 TangramFP
  with isolation latches, 4 mode supplied with the operands) and `corr` (0 none, 1 MSB correction,
  2 rounding of A and C). `src_t/`: latch-free timing view for static timing.
- `tb/`: testbenches; `gentrace.py` generates the DNN operand traces (not included, regenerate with it),
  `addmode.py` adds the mode column.
- `synth.tcl`, `run_synth.sh`: place and route; `run_power*.sh`, `power.tcl`: post-route timing simulation,
  SAIF, and `report_power`; `synth_t.tcl`, `run_synth_t.sh`: timing view; `verify_mac.sh`: netlist versus RTL.
- `results/`: power summaries (`power_summary*.txt`, values in mW) and area/timing summaries per variant.

## `fpnew/`

`fpnew_mac16.sv` wraps the FP16 FMA of FPnew (https://github.com/openhwgroup/cvfpu, commit
`77811635cb7e8649f1d9484733ee6a0bdb44a0e6`) with the interface of our MAC; `synth_fpnew.tcl` implements it;
`../hw16/run_power_fpnew.sh` measures it. The FPnew sources are not included; clone them into `fpnew/cvfpu`.

## `arr/`: systolic arrays

- `src/`: final array RTL (`pe.vhd`, `sarray.vhd`) with the latch-free MAC arithmetic and synchronous
  (clock-enable) isolation of Null mode (`tangram = 2`); `src_t/`: timing view.
- `tb/gentile.py`: DNN tile stimulus; `array_tb*.vhd`: testbenches; `check.py`, `diag.py`: checks against
  the exact results and between RTL and netlist.
- `synth_arr.tcl`, `run_arr_v5.sh`, `run_power_arr.sh`, `run_rtl.sh`: implementation and simulation flow.
- `results/`: area and timing summaries used in Sec. 6.3.6. Array power is not reported in the paper,
  because the post-route timing simulations did not reproduce the RTL in all cases.

## `asic/`: standard-cell evaluation

There is no VHDL front end for Yosys here, so Vivado elaborates the VHDL into a primitive netlist
(`vfront.tcl`), which Yosys re-synthesizes to the Nangate 45 nm library (`ysyn.ys.in`, `latch_map.v`).
`sta.tcl` (OpenSTA) reports timing and power; `run_pw.sh` simulates each gate-level netlist on a trace
(zero delay) and annotates the switching activity; `rtl_mac.sh` gives the RTL reference. `run_all2.sh` and
`run_inmac.sh` run all variants; `sweep_delay.sh` checks the sensitivity of the delays to the ABC target.
The Nangate cell models used for simulation are generated with
`yosys -p "read_liberty -ignore_miss_func <lib>; write_verilog nangate_cells.v"`.
`results/`: area and delay per variant (`asic_summary.txt`) and power per variant and workload
(`asic_power*.txt`, mW, with the number of operations that differ from the RTL; the latch variants differ
only in the first operations, before every isolation latch has been enabled once).
