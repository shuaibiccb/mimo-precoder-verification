#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

if [[ "${GENERATE_VECTORS:-0}" == "1" ]]; then
  python3 -m scripts.generate_rtl_vectors \
    --random-count "${RANDOM_COUNT:-1000}" \
    --seed "${SEED:-20260803}"
fi

required_vectors=(
  build/rtl_vectors/complex_mult.txt
  build/rtl_vectors/complex_mac.txt
  build/rtl_vectors/fixed_round_sat.txt
  build/rtl_vectors/precoder_core.txt
)

for vector_file in "${required_vectors[@]}"; do
  if [[ ! -s "$vector_file" ]]; then
    echo "ERROR: missing or empty vector file: $vector_file" >&2
    echo "Generate vectors on Windows and upload build/rtl_vectors first." >&2
    exit 1
  fi
done

mkdir -p build/vcs

run_test() {
  local name=$1
  local testbench=$2
  shift 2
  vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all \
    "$@" "$testbench" \
    -top "tb_${name}" -o "build/vcs/simv_${name}" \
    -l "build/vcs/compile_${name}.log"
  "build/vcs/simv_${name}" -l "build/vcs/run_${name}.log"
}

run_test complex_mult tb/unit/tb_complex_mult.sv \
  rtl/complex_mult.sv
run_test complex_mac tb/unit/tb_complex_mac.sv \
  rtl/complex_mult.sv rtl/complex_mac.sv
run_test fixed_round_sat tb/unit/tb_fixed_round_sat.sv \
  rtl/fixed_round_sat.sv
run_test precoder_core tb/core/tb_precoder_core.sv \
  rtl/complex_mult.sv \
  rtl/complex_mac.sv \
  rtl/fixed_round_sat.sv \
  rtl/matrix_storage.sv \
  rtl/symbol_buffer.sv \
  rtl/precoder_core.sv \
  tb/assertions/precoder_core_sva.sv

echo "PASS: all VCS unit/core tests completed"
