#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"
mkdir -p reports/generated

if ! command -v yosys >/dev/null 2>&1; then
  echo "ERROR: yosys is not available in PATH" >&2
  exit 1
fi

yosys -l reports/generated/yosys.log synth/run_yosys.ys
echo "Yosys report: reports/generated/yosys.log"
echo "Yosys netlist: reports/generated/axi_precoder_wrapper_yosys.v"
