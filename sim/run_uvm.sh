#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"
UVM_HOME=${UVM_HOME:-/cad/synopsys/vcs-mx/O-2018.09-SP1/etc/uvm-1.2}
if [[ ! -f "$UVM_HOME/src/uvm_pkg.sv" && ! -f "$UVM_HOME/uvm_pkg.sv" ]]; then
  echo "ERROR: UVM 1.2 was not found under $UVM_HOME" >&2
  exit 1
fi

mkdir -p build/vcs/uvm
if [[ "${SKIP_COMPILE:-0}" != "1" ]]; then
  coverage_compile_opts=()
  if [[ "${SVA_COVERAGE:-0}" == "1" ]]; then coverage_compile_opts=(-cm assert); fi
  vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all \
    "${coverage_compile_opts[@]}" \
    -ntb_opts uvm-1.2 \
    tb/uvm/axi_stream_if.sv \
    tb/uvm/axi_lite_if.sv \
    tb/uvm/performance_if.sv \
    tb/uvm/precoder_uvm_pkg.sv \
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
    tb/assertions/precoder_core_sva.sv \
    tb/assertions/axi_precoder_sva.sv \
    tb/uvm/tb_precoder_uvm.sv \
    -top tb_precoder_uvm -o build/vcs/uvm/simv_uvm \
    -l build/vcs/uvm/compile.log
fi

if [[ ! -x build/vcs/uvm/simv_uvm ]]; then
  echo "ERROR: UVM simulator is missing; run without SKIP_COMPILE=1 first" >&2
  exit 1
fi

uvm_test=${UVM_TEST:-precoder_base_test}
seed=${SEED:-20260808}
vectors=${VECTORS:-12}
run_log=${RUN_LOG:-build/vcs/uvm/run.log}
coverage_run_opts=()
if [[ "${SVA_COVERAGE:-0}" == "1" ]]; then
  coverage_run_opts=(-cm assert -cm_dir "${SVA_VDB:-build/vcs/uvm/sva.vdb}")
fi
build/vcs/uvm/simv_uvm \
  +UVM_TESTNAME="$uvm_test" +ntb_random_seed="$seed" +VECTORS="$vectors" \
  +STRICT_AXI_INPUT \
  ${EXTRA_PLUSARGS:-} \
  "${coverage_run_opts[@]}" \
  -l "$run_log"
if grep -Eq "UVM_ERROR[[:space:]]*:[[:space:]]*[1-9]|UVM_FATAL[[:space:]]*:[[:space:]]*[1-9]|Assertion.*failed|Offending|^[[:space:]]*Error:" "$run_log"; then
  echo "ERROR: UVM or SVA errors were reported" >&2
  exit 1
fi
case "$uvm_test" in
  precoder_base_test)
    grep -q "UVM scoreboard checked 4 output beats" "$run_log"
    ;;
  precoder_random_test)
    grep -q "\[PHASE8\].*checked" "$run_log"
    grep -q "\[PHASE9_SVA_AXI\].*reads=[1-9]" "$run_log"
    grep -Eq "\[PHASE9_SVA_CORE\].*busy_commits=[2-9].*bank_switches=[2-9]" "$run_log"
    ;;
  precoder_numeric_worst_test)
    grep -q "\[PHASE10\].*4 bit-exact RTL outputs and saturation flags" "$run_log"
    grep -q "\[PHASE9_SVA_CORE\].*accepted=1 completed=1" "$run_log"
    ;;
  precoder_performance_test)
    grep -q "\[PHASE11\].*throughput_at_100MHz" "$run_log"
    grep -q "\[PHASE9_SVA_CORE\].*accepted=${vectors} completed=${vectors}" "$run_log"
    ;;
  precoder_python_golden_test)
    grep -q "\[PHASE12\].*vectors=${vectors} python_checked=${vectors}.*busy_commits=1" "$run_log"
    grep -q "\[PHASE9_SVA_CORE\].*accepted=${vectors} completed=${vectors}.*busy_commits=1" "$run_log"
    ;;
  precoder_8x8_test)
    grep -q "\[PHASE13\].*8x8 UVM reference checked" "$run_log"
    grep -q "\[PHASE9_SVA_AXI\].*input_beats=16 output_beats=16" "$run_log"
    grep -q "\[PHASE9_SVA_CORE\].*accepted=2 completed=2.*busy_commits=1" "$run_log"
    ;;
  precoder_12bit_test)
    grep -q "\[PHASE15\].*12-bit Q1.10 8x8 reference checked" "$run_log"
    grep -q "\[PHASE9_SVA_AXI\].*input_beats=8 output_beats=8" "$run_log"
    grep -q "\[PHASE9_SVA_CORE\].*accepted=1 completed=1" "$run_log"
    ;;
  precoder_quantization_test)
    grep -q "\[PHASE16\].*runtime quantization checked" "$run_log"
    grep -q "\[PHASE9_SVA_AXI\].*input_beats=16 output_beats=16" "$run_log"
    grep -q "\[PHASE9_SVA_CORE\].*accepted=4 completed=4" "$run_log"
    ;;
  *)
    echo "ERROR: run_uvm.sh has no completion check for $uvm_test" >&2
    exit 1
    ;;
esac
echo "PASS: $uvm_test completed with seed $seed"
