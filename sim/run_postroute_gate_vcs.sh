#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
export DC_MAPPED_NETLIST="$ROOT_DIR/reports/generated/icc/precoder_core_postroute_sim.v"
export SDF_FILE="$ROOT_DIR/reports/generated/icc/precoder_core_postroute.sdf"
export SDF=1

bash "$ROOT_DIR/sim/run_gate_vcs.sh"
