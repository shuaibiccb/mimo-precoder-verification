#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"
mkdir -p reports/generated/icc
module purge
module load synopsys/pts/O-2018.06-SP5
pt_shell -f pnr/run_pt_postroute.tcl 2>&1 | tee reports/generated/icc/pt_postroute.log
