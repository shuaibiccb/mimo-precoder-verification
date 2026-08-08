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
  vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all \
    -ntb_opts uvm-1.2 \
    tb/uvm/axi_stream_if.sv \
    tb/uvm/axi_lite_if.sv \
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
build/vcs/uvm/simv_uvm \
  +UVM_TESTNAME="$uvm_test" +ntb_random_seed="$seed" +VECTORS="$vectors" \
  -l "$run_log"
if grep -Eq "UVM_ERROR[[:space:]]*:[[:space:]]*[1-9]|UVM_FATAL[[:space:]]*:[[:space:]]*[1-9]" "$run_log"; then
  echo "ERROR: UVM errors were reported" >&2
  exit 1
fi
if [[ "$uvm_test" == "precoder_base_test" ]]; then
  grep -q "UVM scoreboard checked 4 output beats" "$run_log"
else
  grep -q "\[PHASE8\].*checked" "$run_log"
fi
echo "PASS: $uvm_test completed with seed $seed"
