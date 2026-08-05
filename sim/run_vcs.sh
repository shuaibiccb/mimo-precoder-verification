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
mkdir -p build/vcs/waves

wave_compile_opts=()
if [[ "${WAVES:-0}" == "1" ]]; then
  verdi_root="${VERDI_HOME:-${NOVAS_HOME:-}}"
  if [[ -z "$verdi_root" ]]; then
    echo "ERROR: WAVES=1 requires a loaded Verdi environment." >&2
    echo "Run: module load synopsys/verdi/O-2018.09-SP1" >&2
    exit 1
  fi

  pli_dir=""
  for candidate in \
    "$verdi_root/share/PLI/VCS/LINUX64" \
    "$verdi_root/share/PLI/VCS/linux64" \
    "$verdi_root/share/PLI/VCS"; do
    if [[ -f "$candidate/novas.tab" && -f "$candidate/pli.a" ]]; then
      pli_dir="$candidate"
      break
    fi
  done
  if [[ -z "$pli_dir" ]]; then
    echo "ERROR: cannot find Verdi VCS PLI under $verdi_root" >&2
    exit 1
  fi
  wave_compile_opts=(+define+FSDB -P "$pli_dir/novas.tab" "$pli_dir/pli.a")
fi

run_test() {
  local name=$1
  local testbench=$2
  shift 2
  vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all \
    "${wave_compile_opts[@]}" \
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
run_test precoder_hot_update tb/core/tb_precoder_hot_update.sv \
  rtl/complex_mult.sv \
  rtl/complex_mac.sv \
  rtl/fixed_round_sat.sv \
  rtl/matrix_storage.sv \
  rtl/symbol_buffer.sv \
  rtl/precoder_core.sv \
  tb/assertions/precoder_core_sva.sv

echo "PASS: all VCS unit/core tests completed"
