#!/usr/bin/env bash
# Complete RTL-to-GDSII flow. Run inside IIC-OSIC-TOOLS at this project root.
set -euo pipefail

./run_flow.sh
./check_fault_injection.sh

# Determine T_min at the typical corner, round it to 0.01 ns, and confirm it.
wns=$(awk '/worst slack/ {value=$NF} END {print value}' report/sta_10ns.log)
if [[ -z "$wns" || ! "$wns" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Could not parse worst slack from report/sta_10ns.log" >&2
  exit 1
fi
t_min=$(awk -v wns="$wns" 'BEGIN { printf "%.2f", 10.0 - wns }')
CLOCK_PERIOD="$t_min" sta sta/sta.tcl | tee report/sta_tmin.log

# Assignment rule: 1.2*T_min rounded upward to the next 0.5 ns.  The value
# below is the required first PnR attempt; do not overwrite config.json after
# a later timing-closure retry has selected a larger successful period.
pnr_period=$(awk -v t="$t_min" 'BEGIN { x=1.2*t; printf "%.1f", int(x/0.5 + 0.999999)*0.5 }')
configured_period=$(awk -F: '/"CLOCK_PERIOD"/ {gsub(/[,[:space:]]/, "", $2); print $2}' pnr/config.json)
printf 'WNS_10NS=%s\nT_MIN_NS=%s\nINITIAL_PNR_CLOCK_PERIOD_NS=%s\nCONFIGURED_PNR_CLOCK_PERIOD_NS=%s\n' "$wns" "$t_min" "$pnr_period" "$configured_period" | tee report/derived_timing.env

# run_flow.sh selects SKY130 in a child shell. Pin it again here because
# LibreLane reads its PDK choice from this runner's environment and config.
export PDK_ROOT=/foss/pdks
export PDK=sky130A
export PDKPATH="$PDK_ROOT/$PDK"
export STD_CELL_LIBRARY=sky130_fd_sc_hd
( cd pnr && librelane config.json ) | tee report/librelane.log

run_dir=$(find pnr/runs -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
if [[ -z "$run_dir" ]]; then
  echo "LibreLane did not create a run directory." >&2
  exit 1
fi

metrics=$(find "$run_dir/final" -type f -name metrics.json -print -quit)
gds=$(find "$run_dir/final" -type f -name '*.gds' -print -quit)
if [[ -z "$metrics" || -z "$gds" ]]; then
  echo "LibreLane finished without final metrics.json or GDSII." >&2
  exit 1
fi
cp "$metrics" pnr/metrics.json
cp "$gds" pnr/mult_array.gds
printf 'LIBRELANE_RUN=%s\n' "$run_dir" | tee report/librelane_run.env
echo "Complete flow finished. Final artifacts: pnr/metrics.json and pnr/mult_array.gds"
