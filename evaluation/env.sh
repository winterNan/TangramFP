# Tool and data locations used by the evaluation scripts. Every script sources this file; override any
# variable in the environment, e.g.  VIVADO_SETTINGS=/opt/Xilinx/Vivado/2018.3/settings64.sh ./run_fpga.sh
EVAL=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
: "${VIVADO_SETTINGS:=$HOME/tools/Xilinx/Vivado/2018.3/settings64.sh}"   # Vivado 2018.3
: "${EDA_BIN:=$HOME/eda/bin}"                                             # yosys and sta (OpenSTA)
: "${YOSYS_SHARE:=$(dirname "$EDA_BIN")/share/yosys}"                     # Yosys data directory
: "${NANGATE45_LIB:=$EVAL/oss/nangate45/lib/NangateOpenCellLibrary_typical.lib}"
command -v vivado > /dev/null || . "$VIVADO_SETTINGS"
