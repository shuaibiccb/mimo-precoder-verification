#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

python3 -m scripts.generate_rtl_vectors --random-count "${RANDOM_COUNT:-1000}" \
  --seed "${SEED:-20260803}"

mkdir -p build/vcs

run_test() {
  local name=$1
  shift
  vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all \
    "$@" "tb/unit/tb_${name}.sv" \
    -top "tb_${name}" -o "build/vcs/simv_${name}" \
    -l "build/vcs/compile_${name}.log"
  "build/vcs/simv_${name}" -l "build/vcs/run_${name}.log"
}

run_test complex_mult rtl/complex_mult.sv
run_test complex_mac rtl/complex_mult.sv rtl/complex_mac.sv
run_test fixed_round_sat rtl/fixed_round_sat.sv

echo "PASS: all phase-2 VCS unit tests completed"

