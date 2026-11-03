# TangramFP evaluation

This folder holds the code of the experiments in the journal version of TangramFP, which extends the
SBAC-PAD 2024 paper. The conference artefacts in `hw/` and `sw/` are unchanged. Section, table and figure
numbers refer to the journal article.

The scripts were run on Linux with Vivado 2018.3 (free licence, Kintex-7 `xc7k160tffg676-2`), Yosys 0.58,
OpenSTA 2.7.0, and PyTorch 2.1 on CPU. They work from any checkout location; paths are relative to the script.

## Configuration

Tool locations are set in `env.sh`, which every hardware script sources. Each variable can be overridden
in the environment:

| Variable | Default | Used for |
|---|---|---|
| `VIVADO_SETTINGS` | `~/tools/Xilinx/Vivado/2018.3/settings64.sh` | Vivado (skipped if `vivado` is already on `PATH`) |
| `EDA_BIN` | `~/eda/bin` | `yosys` and `sta` (OpenSTA) |
| `YOSYS_SHARE` | `$EDA_BIN/../share/yosys` | Yosys data directory |
| `NANGATE45_LIB` | `oss/nangate45/lib/NangateOpenCellLibrary_typical.lib` | Nangate 45 nm liberty file |

The Python scripts look for data under `data/` and accept these overrides:

| Variable | Default |
|---|---|
| `IMAGENETTE_VAL` | `data/imagenette2-320/val` |
| `CIFAR10_DIR` | `data/cifar-10-batches-py` |
| `LLAMA_CKPT`, `LLAMA_TOKENIZER` | `data/llama-2-7b`, `data/llama-2-7b/tokenizer.model` |

Example: `VIVADO_SETTINGS=/opt/Xilinx/Vivado/2018.3/settings64.sh fpga_mac/run_msb.sh`.

| Folder | Contents | Paper |
|---|---|---|
| `emulator/` | Batched FP16 TangramFP emulator and the application-level experiments | Sec. 6.3, Table 6, Fig. 14 |
| `rtl/` | VHDL of the complete MAC, the systolic array, and the testbenches | all hardware results |
| `traces/` | DNN operand traces that drive the MAC simulations, and their generator | Tables 7–8 |
| `fpga_mac/` | Complete FP16 MACs on the FPGA: implementation, power, controller cost | Sec. 6.4.1, Table 7 |
| `asic_45nm/` | Standard-cell flow (Nangate 45 nm): synthesis, timing, gate-level power | Sec. 6.4.2, Tables 8 and 10 |
| `fpnew/` | FPnew FP16 FMA baseline in the same FPGA flow | Table 7 |
| `systolic_array/` | 4x4 and 8x8 systolic arrays driven by DNN tiles: implementation, power, output error | Sec. 6.6.2, Table 12, Figs. 18 and 20 |
| `vivado_projects/` | Script that creates Vivado GUI projects of the evaluated designs | — |

Not included: datasets and model weights (`data/`), the Nangate45 platform files (`oss/nangate45`), the FPnew
sources (`fpnew/cvfpu`), and all outputs (accuracy results, tile stimuli, netlists, reports, logs, figure data).
Running the scripts recreates the outputs: the accuracy runs write JSON files to `results/`, and each hardware
flow writes its run folders and summary files next to its scripts.

## `rtl/`

- `mac/`: the complete FP16 MAC (`macw.vhd`, top entity `MACW`) used for the single-MAC results. It registers
  its operands and its 32-bit sum. The generic `tangram` selects the design of Table 7: 0 standard MAC (*i*);
  3/4 mode computed inside the MAC in the same cycle, without/with isolation latches (*ii*/*iii*); 2/1/5
  registered mode without isolation (*iv*), with isolation latches (*v*), or with clock-enable isolation (*vi*).
  `corr` selects the AC correction: 0 none, 1 MSB (+MSB), 2 rounding (+Ro).
- `mac_breakdown/macw.vhd`: the same MAC with the mode generation in its own entity, for the controller-cost
  breakdown; the other files come from `mac/`.
- `array/`: the systolic array (`sarray.vhd`, `pe.vhd`) with output-stationary PEs that round their FP16 running
  sum to nearest even. In the PE, `tangram` = 0 is the standard PE and 2 the TangramFP PE with registered mode
  and clock-enable isolation; `corr` as above.
- `tb/`: `macw_tb.vhd` (MAC on a trace), `array_tb.vhd` (array netlist), `array_tb_rtl.vhd` (array RTL with all
  running sums dumped).

## `emulator/`

- `tfp16.c`: batched TangramFP FP16 dot-product emulator (group mode selection, binary32 accumulator,
  selectable AC correction: truncation, MSB correction, rounding of A and C). With the same settings it is
  bit-exact against `kacy_f16_main()` of `sw/tangram16/c_src/kacy16.c` (`test_equiv.py`, 20,000 random cases).
  Build with `make` (needs F16C and OpenMP).
- `tfp.py`: ctypes front end, and `patch_functional()`, which routes `F.conv2d`, `F.linear` and
  `F.scaled_dot_product_attention` through the emulator for the duration of a run.
- `eval_img.py` (ImageNet classifiers on Imagenette), `eval_llm.py` (GPT-2 Large), `eval_llama.py`
  (Llama-2-7B, Meta checkpoint), `train_cifar.py` (CIFAR-10 training of a ResNet-8 and a small ViT with
  emulated forward and backward passes and dynamic loss scaling), `test_grad.py`.
- Experiments:
  - `run_accuracy.sh`: Table 6 (image classifiers, Llama-2-7B, 8-epoch training).
  - `run_thresholds.sh`: GPT-2 Large and the Skip-BD/AC and Null threshold study.
  - `run_llama_null_threshold.sh`: Llama-2-7B with Null at s >= 13 and without Null.
  - `run_msb_inference.sh`, `run_msb_training.sh`: the MSB-correction entries of Table 6.
  - `run_fpnew_accuracy.sh`: the FPnew rows (FP16 running sum rounded after every MAC).

Each run writes one JSON file to `results/` with its settings (`args`) and, per arithmetic configuration
(`fp32`, `fp16`, `trunc`, `msb+bd`, `rte`, `fpnew`), accuracy or perplexity and the mode share. `thr1` is the
Skip-BD/AC threshold and `thr2` the Null threshold (Null for s >= thr2).

## `traces/`

`net_<network>.txt`: consecutive MACs of dot products sampled from all layers of ResNet18, ResNet50,
MobileNetV2 and ViT-B/16; `syn_<mode>.txt`: synthetic streams that keep one mode; `m_*`: the same streams with
the mode as a fourth column. Regenerate them with `gentrace.py` and `addmode.py`.

## `fpga_mac/`: complete MACs on the FPGA (Table 7)

- `synth_w.tcl`: out-of-context place and route at 20 ns with a chosen placement directive.
- `run_fpga.sh`: builds designs *i*–*vi* and their corrected variants with three placement directives and
  measures their power on the four networks; `run_msb.sh` adds *vi*+MSB.
- `rtl_macw.sh`: RTL simulation on a trace; `pw_w.sh`: post-route timing simulation, SAIF, `report_power`
  (`power.tcl`), and a cycle-by-cycle check against the RTL; `acc_macw.py`: output error against the exact result.
- `controller_cost.sh`, `controller_cost_modegen.sh`, `synth_w_nf.tcl`, `synth_w_bd.tcl`: hierarchy-kept builds
  that separate the LUTs, flip-flops and power of the mode generation.
- Outputs: `fpga_summary.txt` and `msb_mac.txt` (LUTs, flip-flops, delay), `fpga_power.txt` (power in mW per
  design and network), `ctrl_bd.txt` (controller cost).

## `asic_45nm/`: standard-cell evaluation (Tables 8 and 10)

There is no VHDL front end for Yosys here, so Vivado elaborates the VHDL into a primitive netlist
(`vfront_w.tcl`), which Yosys re-synthesizes to the Nangate 45 nm library (`ysyn.ys.in`, `latch_map.v`).
`run_asicw_all.sh` runs every design: `run_asic_w.sh` synthesizes it and reports area and delay with OpenSTA
(`sta_w.tcl`); `run_pw_w.sh` simulates the gate-level netlist on each trace (zero delay), annotates the
switching activity, and reports power; `run_pw_bd.sh` with `groups.py` and `sta_bd.tcl` splits the power into
flip-flops, mode registers and isolation latches. The Nangate cell models used for simulation are generated with
`yosys -p "read_liberty -ignore_miss_func <lib>; write_verilog nangate_cells.v"`.
Outputs: `asicw_summary.txt`, `asicw_power.txt`, `asicw_breakdown.txt`.

## `fpnew/`

`fpnew_macw.sv` wraps the FP16 FMA of FPnew (https://github.com/openhwgroup/cvfpu, commit
`77811635cb7e8649f1d9484733ee6a0bdb44a0e6`) with the ports of the complete MAC and the same input registers.
Clone the FPnew sources into `fpnew/cvfpu`. `run_fpnew_w.sh` builds it (`synth_fpnew_w.tcl`; `w_in1` is the
reported design) and `pw_fpnew_w.sh` measures its power, checking every output with `chk_fma.py`.

## `systolic_array/`

- `gentile.py`: DNN tile stimulus (complete dot products, layers sampled in proportion to their number of dot
  products); `run_arrays.sh` calls it and writes the tiles to `stim/`. It also prints the tile statistics of
  Table 12.
- `synth_arr.tcl`: place and route of an array; `run_rtl.sh`: RTL simulation.
- `run_arrays.sh` (standard, *vi*, *vi*+Ro) and `run_arrays_msb.sh` (*vi*+MSB): implementation, then power
  from the post-route functional netlist on each network, checked cycle by cycle against the RTL. Outputs:
  `arrays_power.txt` and `arrays_msb_power.txt` (power in mW and mismatch counts).
- `gk_err.py` with `tile_err.py`: output error of every final PE output against a float64 reference,
  |array output − reference| / max |reference| of its tile (Fig. 20).
- `synth_pe_nf.tcl` (one PE placed with its hierarchy kept; arguments `<outdir> 20 2 0 ../rtl/array`) and
  `export_place.tcl` (cell placement of a routed checkpoint): the data of Fig. 18.

## `vivado_projects/`

`make_projects.tcl` creates one Vivado project per design under `vivado_projects/proj/`; see
`vivado_projects/README.md`.
