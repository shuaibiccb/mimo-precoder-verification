#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

runs=${RUNS:-20}
vectors=${VECTORS:-50}
base_seed=${BASE_SEED:-20260808}
golden_file=${GOLDEN_FILE:-tb/vectors/stage12_golden_vectors.txt}
manifest_file=${MANIFEST_FILE:-tb/vectors/stage12_manifest.json}
report_dir=build/vcs/uvm/python_golden
mkdir -p "$report_dir"
rm -rf "$report_dir/sva_report" "$report_dir"/seed_*.vdb
rm -f "$report_dir"/seed_*.log "$report_dir/summary.csv" "$report_dir/summary.md"

if [[ ! -f "$golden_file" || ! -f "$manifest_file" ]]; then
  echo "ERROR: stage-12 golden vectors or manifest are missing" >&2
  exit 1
fi
expected_sha=$(sed -n 's/.*"golden_sha256": "\([0-9a-f]*\)".*/\1/p' "$manifest_file")
actual_sha=$(sha256sum "$golden_file" | awk '{print $1}')
if [[ -z "$expected_sha" || "$actual_sha" != "$expected_sha" ]]; then
  echo "ERROR: stage-12 golden vector SHA-256 does not match the manifest" >&2
  exit 1
fi

summary="$report_dir/summary.csv"
echo "simulation_seed,block,data_seed,qam,vectors,busy_commits,max_impl_evm,max_end_to_end_evm" > "$summary"

for ((run=0; run<runs; run++)); do
  seed=$((base_seed + run))
  skip_compile=1
  if [[ $run -eq 0 ]]; then skip_compile=0; fi
  log="$report_dir/seed_${seed}.log"
  echo "Python golden regression $((run+1))/$runs simulation_seed=$seed block=$run vectors=$vectors"
  SKIP_COMPILE=$skip_compile UVM_TEST=precoder_python_golden_test \
    SVA_COVERAGE=1 SVA_VDB="$report_dir/seed_${seed}.vdb" \
    SEED=$seed VECTORS=$vectors RUN_LOG="$log" \
    EXTRA_PLUSARGS="+GOLDEN_FILE=$golden_file +DATASET_INDEX=$run" \
    bash sim/run_uvm.sh
  line=$(grep "\[PHASE12\].*python_checked=" "$log" | head -1)
  if [[ ! $line =~ block=([0-9]+).*data_seed=([0-9]+).*qam=([0-9]+).*vectors=([0-9]+).*python_checked=([0-9]+).*busy_commits=([0-9]+).*bank1_version=([0-9]+).*max_impl_evm=([0-9.eE+-]+).*max_end_to_end_evm=([0-9.eE+-]+) ]]; then
    echo "ERROR: could not parse PHASE12 results from $log" >&2
    exit 1
  fi
  if [[ "${BASH_REMATCH[4]}" != "${BASH_REMATCH[5]}" ]]; then
    echo "ERROR: Python checker did not check every vector in $log" >&2
    exit 1
  fi
  echo "$seed,${BASH_REMATCH[1]},${BASH_REMATCH[2]},${BASH_REMATCH[3]},${BASH_REMATCH[4]},${BASH_REMATCH[6]},${BASH_REMATCH[8]},${BASH_REMATCH[9]}" >> "$summary"
done

vdbs=("$report_dir"/seed_*.vdb)
if [[ ! -d "${vdbs[0]}" ]]; then
  echo "ERROR: no stage-12 SVA coverage database was generated" >&2
  exit 1
fi
urg -full64 -dir "${vdbs[@]}" \
  -report "$report_dir/sva_report" \
  -log "$report_dir/sva_urg.log"
if [[ ! -f "$report_dir/sva_report/dashboard.html" ]]; then
  echo "ERROR: stage-12 SVA coverage report was not generated" >&2
  exit 1
fi

{
  echo "# Stage-12 Python Golden Regression"
  echo
  echo "- Golden SHA-256: \`$actual_sha\`"
  echo "- Runs: $runs"
  echo "- Total vectors: $((runs * vectors))"
  echo
  echo "| Modulation | Runs | Vectors | Maximum implementation EVM | Maximum end-to-end EVM |"
  echo "|---|---:|---:|---:|---:|"
  for qam in 4 16 64; do
    if [[ $qam == 4 ]]; then modulation=QPSK; else modulation=${qam}QAM; fi
    awk -F, -v q="$qam" -v modulation="$modulation" 'NR>1 && $4==q {runs++; vectors+=$5; if ($7>max_impl) max_impl=$7; if ($8>max_e2e) max_e2e=$8} END {printf "| %s | %d | %d | %.6e | %.6e |\n",modulation,runs,vectors,max_impl,max_e2e}' "$summary"
  done
} > "$report_dir/summary.md"

echo "PASS: $runs Python golden seeds completed ($((runs * vectors)) vectors)"
echo "CSV summary: $summary"
echo "Markdown summary: $report_dir/summary.md"
echo "SVA coverage report: $report_dir/sva_report/dashboard.html"
