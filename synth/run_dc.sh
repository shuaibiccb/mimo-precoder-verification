#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"
mkdir -p reports/generated/dc

if [[ -z "${DC_TARGET_LIBRARY:-}" ]]; then
  echo "ERROR: export DC_TARGET_LIBRARY=/absolute/path/to/standard_cell.db" >&2
  exit 2
fi
if ! command -v dc_shell >/dev/null 2>&1; then
  echo "ERROR: dc_shell is not available in PATH" >&2
  exit 1
fi

dc_shell -f synth/run_dc.tcl | tee reports/generated/dc/dc_shell.log
echo "Design Compiler reports: reports/generated/dc/"
