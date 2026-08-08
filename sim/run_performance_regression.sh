#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

runs=${RUNS:-20}
vectors=${VECTORS:-12}
base_seed=${BASE_SEED:-20260808}
report_dir=build/vcs/uvm/performance
mkdir -p "$report_dir"
summary="$report_dir/summary.csv"
echo "seed,profile,vectors,min_latency,avg_latency,max_latency,input_stalls,output_stalls,throughput_at_100mhz" > "$summary"

for ((run=0; run<runs; run++)); do
  seed=$((base_seed + run))
  skip_compile=1
  if [[ $run -eq 0 ]]; then skip_compile=0; fi
  case $((run % 4)) in
    0) profile=ideal; stall=0; periodic=0; burst=0 ;;
    1) profile=random20; stall=20; periodic=0; burst=0 ;;
    2) profile=mixed; stall=35; periodic=3; burst=0 ;;
    3) profile=long_burst; stall=10; periodic=0; burst=8 ;;
  esac
  log="$report_dir/seed_${seed}_${profile}.log"
  echo "Performance regression $((run+1))/$runs seed=$seed profile=$profile"
  SKIP_COMPILE=$skip_compile UVM_TEST=precoder_performance_test \
    SEED=$seed VECTORS=$vectors RUN_LOG="$log" \
    EXTRA_PLUSARGS="+STALL_PERCENT=$stall +PERIODIC_STALL_EVERY=$periodic +STALL_BURST_CYCLES=$burst" \
    bash sim/run_uvm.sh
  line=$(grep "\[PHASE11\].*vectors=" "$log" | head -1)
  if [[ ! $line =~ vectors=([0-9]+).*min_latency=([0-9]+).*avg_latency=([0-9.]+).*max_latency=([0-9]+).*input_stalls=([0-9]+).*output_stalls=([0-9]+).*throughput_at_100MHz=([0-9.]+) ]]; then
    echo "ERROR: could not parse PHASE11 metrics from $log" >&2
    exit 1
  fi
  echo "$seed,$profile,${BASH_REMATCH[1]},${BASH_REMATCH[2]},${BASH_REMATCH[3]},${BASH_REMATCH[4]},${BASH_REMATCH[5]},${BASH_REMATCH[6]},${BASH_REMATCH[7]}" >> "$summary"
done

echo "PASS: $runs performance seeds completed ($((runs * vectors)) vectors)"
echo "Performance summary: $summary"
