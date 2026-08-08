#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

runs=${RUNS:-20}
vectors=${VECTORS:-12}
base_seed=${BASE_SEED:-20260808}
mkdir -p build/vcs/uvm/regression
rm -rf build/vcs/uvm/regression/sva_report build/vcs/uvm/regression/seed_*.vdb \
  build/vcs/uvm/regression/precoder_8x8.vdb

for ((run=0; run<runs; run++)); do
  seed=$((base_seed + run))
  skip_compile=1
  if [[ $run -eq 0 ]]; then skip_compile=0; fi
  echo "UVM regression $((run+1))/$runs seed=$seed vectors=$vectors"
  SKIP_COMPILE=$skip_compile UVM_TEST=precoder_random_test \
    SVA_COVERAGE=1 SVA_VDB="build/vcs/uvm/regression/seed_${seed}.vdb" \
    SEED=$seed VECTORS=$vectors \
    RUN_LOG="build/vcs/uvm/regression/seed_${seed}.log" \
    bash sim/run_uvm.sh
done

echo "UVM 8x8 reference test"
UVM_TEST=precoder_8x8_test VECTORS=2 SEED=$((base_seed + runs)) \
  SVA_COVERAGE=1 SVA_VDB="build/vcs/uvm/regression/precoder_8x8.vdb" \
  RUN_LOG="build/vcs/uvm/regression/precoder_8x8.log" SKIP_COMPILE=1 \
  bash sim/run_uvm.sh

vdbs=(build/vcs/uvm/regression/seed_*.vdb)
if [[ ! -d "${vdbs[0]}" ]]; then
  echo "ERROR: no SVA coverage database was generated" >&2
  exit 1
fi
urg -full64 -dir "${vdbs[@]}" build/vcs/uvm/regression/precoder_8x8.vdb \
  -report build/vcs/uvm/regression/sva_report \
  -log build/vcs/uvm/regression/sva_urg.log
if [[ ! -f build/vcs/uvm/regression/sva_report/dashboard.html ]]; then
  echo "ERROR: SVA coverage report was not generated" >&2
  exit 1
fi

echo "PASS: $runs UVM random seeds completed ($((runs * vectors)) vectors)"
echo "SVA coverage report: build/vcs/uvm/regression/sva_report/dashboard.html"
