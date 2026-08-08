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
build/vcs/uvm/simv_uvm +UVM_TESTNAME=precoder_base_test \
  -l build/vcs/uvm/run.log
if grep -Eq "UVM_ERROR[[:space:]]*:[[:space:]]*[1-9]|UVM_FATAL[[:space:]]*:[[:space:]]*[1-9]" build/vcs/uvm/run.log; then
  echo "ERROR: UVM errors were reported" >&2
  exit 1
fi
grep -q "UVM AXI smoke test received 4 output beats" build/vcs/uvm/run.log
echo "PASS: UVM AXI smoke test completed"
