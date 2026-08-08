#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

runs=${RUNS:-20}
vectors=${VECTORS:-12}
base_seed=${BASE_SEED:-20260808}
mkdir -p build/vcs/uvm/regression

for ((run=0; run<runs; run++)); do
  seed=$((base_seed + run))
  skip_compile=1
  if [[ $run -eq 0 ]]; then skip_compile=0; fi
  echo "UVM regression $((run+1))/$runs seed=$seed vectors=$vectors"
  SKIP_COMPILE=$skip_compile UVM_TEST=precoder_random_test \
    SEED=$seed VECTORS=$vectors \
    RUN_LOG="build/vcs/uvm/regression/seed_${seed}.log" \
    bash sim/run_uvm.sh
done

echo "PASS: $runs UVM random seeds completed ($((runs * vectors)) vectors)"
