#!/usr/bin/env bash
# Verify the explicit deliverables in the assignment guide after run_full_flow.sh.
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

errors=0
check_file() {
  if [[ -s "$1" ]]; then
    printf 'OK   %s\n' "$1"
  else
    printf 'MISS %s\n' "$1" >&2
    errors=$((errors + 1))
  fi
}

for file in \
  README.md \
  rtl/full_adder.v rtl/mult_array.v tb/tb_mult.v \
  synth/synth.tcl synth/mult_array_netlist.v synth/mult_array_stat.rpt \
  sta/sta.tcl sta/mult_array_timing.rpt \
  pnr/config.json pnr/metrics.json pnr/mult_array.gds \
  report/report.pdf; do
  check_file "$file"
done

instances=$(rg -c 'full_adder fa_' rtl/mult_array.v || true)
if [[ "$instances" == 12 ]]; then
  echo 'OK   exactly 12 full_adder instances'
else
  echo "FAIL expected 12 full_adder instances, found $instances" >&2
  errors=$((errors + 1))
fi

if rg -n '\*' rtl >/dev/null; then
  echo 'FAIL multiplication operator found in RTL' >&2
  errors=$((errors + 1))
else
  echo 'OK   no multiplication operator in RTL'
fi

if grep -q '^PASS: 256 vectors checked, 0 errors$' report/rtl_simulation.log 2>/dev/null; then
  echo 'OK   RTL exhaustive simulation passed'
else
  echo 'FAIL RTL PASS summary is missing' >&2
  errors=$((errors + 1))
fi

if grep -q '^PASS: 256 vectors checked, 0 errors$' report/gls_simulation.log 2>/dev/null; then
  echo 'OK   gate-level exhaustive simulation passed'
else
  echo 'FAIL gate-level PASS summary is missing' >&2
  errors=$((errors + 1))
fi

if grep -q '^FAIL: 256 vectors checked,' report/fault_injection.log 2>/dev/null; then
  echo 'OK   fault injection produced FAIL and RTL was restored'
else
  echo 'FAIL fault-injection FAIL summary is missing' >&2
  errors=$((errors + 1))
fi

if [[ -s pnr/metrics.json ]]; then
  check_metric() {
    if rg -q "\"$1\"[[:space:]]*:[[:space:]]*$2([,.}]|$)" pnr/metrics.json; then
      echo "OK   $1 = $2"
    else
      echo "FAIL expected $1 = $2" >&2
      errors=$((errors + 1))
    fi
  }
  check_metric 'timing__setup_vio__count' 0
  check_metric 'magic__drc_error__count' 0
  check_metric 'design__lvs_error__count' 0
fi

if [[ "$errors" -eq 0 ]]; then
  echo 'PASS: submission preflight completed with 0 blocking errors'
else
  echo "FAIL: submission preflight found $errors blocking error(s)" >&2
  exit 1
fi
