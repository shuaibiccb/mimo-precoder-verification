#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"
mkdir -p reports/generated/icc
module purge
module load synopsys/icc/O-2018.06-SP5
icc_shell -no_gui -f pnr/run_icc.tcl 2>&1 | tee reports/generated/icc/run_icc.log
