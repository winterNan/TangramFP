# TangramFP

TangramFP is an energy-efficient, bit-parallel floating-point multiply-accumulate (MAC) unit for deep neural
networks. It splits each significand into a high and a low fragment and, depending on the exponent
difference between the product and the running sum, skips the partial products that cannot affect the
rounded result. Four modes (Full, Skip-BD, AC, Null) trade a bounded error for lower switching activity.

This repository contains the RTL, the software emulator, and the evaluation scripts of:

- Y. Yao, X. Chen, H. Atmer, and S. Kaxiras, "TangramFP: Energy-Efficient, Bit-Parallel,
  Multiply-Accumulate for Deep Neural Networks," SBAC-PAD 2024 (`paper/TangramFP.pdf`).
- The extended journal version, whose additional experiments are in `evaluation/`.

## Repository layout

| Path | Contents |
|---|---|
| `hw/Tangram16/` | VHDL of the FP16 TangramFP MAC (1:5:5 split, 32-bit sum) and testbench |
| `hw/Tangram32/` | VHDL of the FP32 TangramFP MAC (1:12:11 split) and unit testbenches |
| `sw/` | C emulator of the TangramFP arithmetic and PyTorch patches that route layers through it |
| `evaluation/` | Experiments of the journal version: batched emulator, complete MACs on FPGA, standard-cell flow, systolic arrays |
| `paper/` | The SBAC-PAD 2024 paper |

## Hardware (`hw/`)

Both MACs are written in VHDL and were developed with Vivado. The top level is `MAC.vhd`; the significand
multiplier is `kacy_mult.vhd` (FP16) or `kacy_32_mult.vhd` (FP32), built on a Dadda tree
(`DaddaMultiplier.vhd`). Mode selection uses the exponent difference s between the running sum and the
product:

| Mode | Partial products computed | Condition |
|---|---|---|
| Full | all | s <= 0 |
| Skip-BD | all except B*D | 0 < s < threshold 1 |
| AC | A*C only | threshold 1 <= s < threshold 2 |
| Null | none | s >= threshold 2 |

See `hw/Tangram16/README.md` and `hw/Tangram32/README.md` for the interfaces.

## Software emulator (`sw/`)

`sw/tangram16` and `sw/tangram32` contain the C implementation of the TangramFP arithmetic (`kacy16.c`,
`kacy32.c`). Build the shared library with:

```sh
cd sw/tangram16/c_src
make
```

`sw/tangram.py` loads the library through ctypes, and the modules in `sw/pytorch_patch/` replace the PyTorch
convolution, linear, and matrix-multiplication operators with emulated versions. The emulator is configured
through environment variables read in `sw/args.py`:

| Variable | Meaning |
|---|---|
| `KACY` | arithmetic: `ORI` (standard FP) or `1_X_Y` (TangramFP) |
| `KACYPW`, `KACYOFFSET` | mode thresholds (threshold 1 = `KACYPW` + `KACYOFFSET`) |
| `KACYCHUNKSIZE` | dot-product chunk length |
| `KACYNUMWORKER` | number of worker processes |
| `KACYDEBUG`, `KACYDUMPON` | debug output and operand dumps (`Y` to enable) |

## Evaluation (`evaluation/`)

The journal version adds application-level accuracy studies (CNNs, a vision Transformer, GPT-2 Large,
Llama-2-7B, and training), complete MACs on a Kintex-7 FPGA, a 45 nm open-source standard-cell flow,
error-correction variants, and 4x4 and 8x8 systolic arrays. `evaluation/README.md` maps each folder to the
tables and figures of the paper and lists the required tools (Vivado 2018.3, Yosys, OpenSTA, PyTorch).

Datasets, model weights, third-party IP, tool outputs, and experiment results are not part of the repository; see
`evaluation/.gitignore` and `evaluation/README.md`.

## Citation

```bibtex
@inproceedings{tangramfp-sbacpad,
  author    = {Yao, Yuan and Chen, Xiaoyue and Atmer, Hannah and Kaxiras, Stefanos},
  title     = {{TangramFP}: Energy-Efficient, Bit-Parallel, Multiply-Accumulate for Deep Neural Networks},
  booktitle = {2024 IEEE 36th International Symposium on Computer Architecture and High Performance
               Computing (SBAC-PAD)},
  address   = {Hilo, HI, USA},
  pages     = {1--12},
  year      = {2024}
}
```

## Contact

Department of Information Technology, Uppsala University, Sweden.
