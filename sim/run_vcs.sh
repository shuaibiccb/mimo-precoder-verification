#!/usr/bin/env bash
# The server uses an older Bash that treats an empty array expansion as an
# unbound variable under `set -u`. Keep fail-fast and pipeline checking while
# allowing optional VCS argument arrays to remain empty.
set -eo pipefail

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
mkdir -p build/vcs/coverage

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
  # -kdb generates the Verdi design database used for hierarchy/source browsing.
  wave_compile_opts=(-kdb +define+FSDB -P "$pli_dir/novas.tab" "$pli_dir/pli.a")
fi

coverage_compile_opts=()
coverage_run_opts=()
core_coverage_sources=()
axi_coverage_sources=()
if [[ "${COVERAGE:-0}" == "1" ]]; then
  if ! command -v urg >/dev/null 2>&1; then
    echo "ERROR: COVERAGE=1 requires urg in PATH" >&2
    exit 1
  fi
  coverage_compile_opts=(-cm line+cond+fsm+tgl+branch+assert)
  coverage_run_opts=(-cm line+cond+fsm+tgl+branch+assert)
  core_coverage_sources=(tb/coverage/precoder_core_coverage.sv)
  axi_coverage_sources=(tb/coverage/axi_precoder_coverage.sv)
  rm -rf \
    build/vcs/simv_* \
    build/vcs/coverage/complex_mult.vdb \
    build/vcs/coverage/complex_mac.vdb \
    build/vcs/coverage/fixed_round_sat.vdb \
    build/vcs/coverage/precoder_core.vdb \
    build/vcs/coverage/precoder_hot_update.vdb \
    build/vcs/coverage/axi_precoder_wrapper.vdb \
    build/vcs/coverage/axi_precoder_stress.vdb \
    build/vcs/coverage/report
fi

run_test() {
  local name=$1
  local testbench=$2
  local run_coverage_opts=()
  shift 2
  if [[ "${COVERAGE:-0}" == "1" ]]; then
    run_coverage_opts=(-cm_dir "build/vcs/coverage/${name}.vdb")
  fi
  vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all \
    "${wave_compile_opts[@]}" \
    "${coverage_compile_opts[@]}" \
    "${run_coverage_opts[@]}" \
    "$@" "$testbench" \
    -top "tb_${name}" -o "build/vcs/simv_${name}" \
    -l "build/vcs/compile_${name}.log"
  "build/vcs/simv_${name}" \
    "${coverage_run_opts[@]}" \
    "${run_coverage_opts[@]}" \
    -l "build/vcs/run_${name}.log"
  if grep -Eq "Assertion.*failed|Offending|^[[:space:]]*Error:" "build/vcs/run_${name}.log"; then
    echo "ERROR: assertion or simulation error detected in build/vcs/run_${name}.log" >&2
    return 1
  fi
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
  tb/assertions/precoder_core_sva.sv \
  "${core_coverage_sources[@]}"
run_test precoder_hot_update tb/core/tb_precoder_hot_update.sv \
  rtl/complex_mult.sv \
  rtl/complex_mac.sv \
  rtl/fixed_round_sat.sv \
  rtl/matrix_storage.sv \
  rtl/symbol_buffer.sv \
  rtl/precoder_core.sv \
  tb/assertions/precoder_core_sva.sv \
  "${core_coverage_sources[@]}"
run_test axi_precoder_wrapper tb/axi/tb_axi_precoder_wrapper.sv \
  rtl/complex_mult.sv \
  rtl/complex_mac.sv \
  rtl/fixed_round_sat.sv \
  rtl/matrix_storage.sv \
  rtl/symbol_buffer.sv \
  rtl/precoder_core.sv \
  rtl/axi_stream_input.sv \
  rtl/axi_stream_output.sv \
  rtl/performance_counters.sv \
  rtl/axi_lite_regs.sv \
  rtl/axi_precoder_wrapper.sv \
  tb/assertions/axi_precoder_sva.sv \
  "${axi_coverage_sources[@]}"
run_test axi_precoder_stress tb/axi/tb_axi_precoder_stress.sv \
  rtl/complex_mult.sv \
  rtl/complex_mac.sv \
  rtl/fixed_round_sat.sv \
  rtl/matrix_storage.sv \
  rtl/symbol_buffer.sv \
  rtl/precoder_core.sv \
  rtl/axi_stream_input.sv \
  rtl/axi_stream_output.sv \
  rtl/performance_counters.sv \
  rtl/axi_lite_regs.sv \
  rtl/axi_precoder_wrapper.sv \
  tb/assertions/axi_precoder_sva.sv

echo "PASS: all VCS unit/core tests completed"
if [[ "${COVERAGE:-0}" == "1" ]]; then
  core_vdb="build/vcs/coverage/precoder_core.vdb"
  hot_update_vdb="build/vcs/coverage/precoder_hot_update.vdb"
  axi_wrapper_vdb="build/vcs/coverage/axi_precoder_wrapper.vdb"
  axi_stress_vdb="build/vcs/coverage/axi_precoder_stress.vdb"
  if [[ ! -d "$core_vdb" || ! -d "$hot_update_vdb" \
        || ! -d "$axi_wrapper_vdb" || ! -d "$axi_stress_vdb" ]]; then
    echo "ERROR: VCS completed without producing the expected coverage databases" >&2
    exit 1
  fi
  urg -full64 -dir "$core_vdb" "$hot_update_vdb" "$axi_wrapper_vdb" "$axi_stress_vdb" \
    -flex_merge drop -flex_merge modules \
    -report build/vcs/coverage/report \
    -log build/vcs/coverage/urg.log
  if [[ ! -f build/vcs/coverage/report/dashboard.html ]]; then
    echo "ERROR: URG completed without producing dashboard.html" >&2
    exit 1
  fi
  echo "Coverage report: build/vcs/coverage/report/dashboard.html"
fi
