#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

module load synopsys/vcs-mx/O-2018.09-SP1

NETLIST="${DC_MAPPED_NETLIST:-$ROOT_DIR/reports/generated/dc/precoder_core_mapped.v}"
CELL_MODEL="${SMIC55_VERILOG_MODEL:-/cad/eda_lib/smic55nm_2020/SCC55NLL_VHS_STDCELL/SCC55NLL_VHS_RVT_lib_V2.1/SCC55NLL_VHS_RVT_V2.1/SCC55NLL_VHS_RVT_V2p1/verilog/scc55nll_vhs_rvt.v}"

if [[ ! -s "$NETLIST" ]]; then
  echo "ERROR: mapped netlist not found: $NETLIST" >&2
  exit 1
fi
if [[ ! -s "$CELL_MODEL" ]]; then
  echo "ERROR: standard-cell Verilog model not found: $CELL_MODEL" >&2
  exit 1
fi

required_vectors=(
  build/rtl_vectors/precoder_core.txt
)
for vector_file in "${required_vectors[@]}"; do
  if [[ ! -s "$vector_file" ]]; then
    echo "ERROR: missing vector file: $vector_file" >&2
    exit 1
  fi
done

mkdir -p build/vcs

run_gate_test() {
  local name=$1
  local testbench=$2
  vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -Dfunctional \
    "$CELL_MODEL" "$NETLIST" "$testbench" \
    -top "tb_${name}" -o "build/vcs/simv_${name}_mapped" \
    -l "build/vcs/compile_${name}_mapped.log"
  "build/vcs/simv_${name}_mapped" -l "build/vcs/run_${name}_mapped.log"
  if grep -Eq "Assertion.*failed|Offending|^[[:space:]]*Error:" \
      "build/vcs/run_${name}_mapped.log"; then
    echo "ERROR: gate simulation failure in $name" >&2
    return 1
  fi
}

run_gate_test precoder_core tb/core/tb_precoder_core.sv
run_gate_test precoder_hot_update tb/core/tb_precoder_hot_update.sv
echo "PASS: zero-delay gate-level tests completed"
