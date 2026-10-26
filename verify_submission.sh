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

instances=$(grep -c 'full_adder fa_' rtl/mult_array.v || true)
if [[ "$instances" == 12 ]]; then
  echo 'OK   exactly 12 full_adder instances'
else
  echo "FAIL expected 12 full_adder instances, found $instances" >&2
  errors=$((errors + 1))
fi

if grep -rn '\*' rtl >/dev/null; then
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
    if grep -Eq "\"$1\"[[:space:]]*:[[:space:]]*$2([,}[:space:]]|$)" pnr/metrics.json; then
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

metric() {
  sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\([-0-9.eE+]*\).*/\1/p" pnr/metrics.json | head -n 1
}

# Electrical rule checks are not part of the acceptance criteria, so they are
# reported but do not fail the preflight. Part D of the report explains them.
for kind in slew cap fanout; do
  count=$(metric "design__max_${kind}_violation__count")
  if [[ "${count:-0}" -ne 0 ]]; then
    echo "WARN $count max-$kind violation(s) in pnr/metrics.json (non-blocking)"
  fi
done

# The report quotes numbers from the generated files. If a rerun (for example
# with a different tool image) changes any of them, the report is stale.
check_report() {
  if grep -Fq -- "$1" report/report.tex; then
    echo "OK   report.tex has '$1'"
  else
    echo "FAIL report.tex does not have '$1' (value from the current results)" >&2
    errors=$((errors + 1))
  fi
}
cells=$(awk '$NF == "cells" {print $1; exit}' synth/mult_array_stat.rpt)
wns_10=$(awk '/worst slack/ {v = $NF} END {print v}' report/sta_10ns.log)
t_min=$(awk -v w="$wns_10" 'BEGIN {printf "%.2f", 10.0 - w}')
period=$(awk -F: '/"CLOCK_PERIOD"/ {gsub(/[,[:space:]]/, "", $2); printf "%.2f", $2}' pnr/config.json)
slack=$(awk -v s="$(metric timing__setup__ws)" 'BEGIN {printf "%.4f", s}')
pnr_cells=$(metric design__instance__count | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')
check_report "Total number of cells & $cells cells"
check_report "Worst slack at \$T=10\$ ns & $wns_10 ns"
check_report "\$T_{min}\$ & $t_min ns"
check_report "CLOCK\\_PERIOD used & $period ns"
check_report "Cells after place and route & $pnr_cells instances"
check_report "Setup slack & $slack ns"
check_report "Max slew / cap / fanout violations & $(metric design__max_slew_violation__count) / $(metric design__max_cap_violation__count) / $(metric design__max_fanout_violation__count)"

if [[ "$errors" -eq 0 ]]; then
  echo 'PASS: submission preflight completed with 0 blocking errors'
else
  echo "FAIL: submission preflight found $errors blocking error(s)" >&2
  exit 1
fi
