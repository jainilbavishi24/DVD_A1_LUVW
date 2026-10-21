#!/usr/bin/env bash
# Fast checks used by GitHub Actions. Requires Icarus Verilog and Yosys.
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

echo '==> Checking scripts and JSON configuration'
bash -n check_fault_injection.sh run-osic.sh run_flow.sh run_full_flow.sh verify_submission.sh ci/test.sh
python3 -m json.tool pnr/config.json >/dev/null
python3 -m json.tool pnr/metrics.json >/dev/null

echo '==> Checking required structural RTL properties'
full_adder_count="$(grep -Ec '^[[:space:]]*full_adder[[:space:]]+fa_' rtl/mult_array.v)"
if [[ "$full_adder_count" -ne 12 ]]; then
  echo "FAIL: expected 12 full_adder instances, found $full_adder_count" >&2
  exit 1
fi
if grep -Rn '\*' rtl; then
  echo 'FAIL: multiplication operator found in synthesizable RTL' >&2
  exit 1
fi
echo 'PASS: structural RTL requirements satisfied'

echo '==> Running exhaustive RTL simulation'
iverilog -g2012 -Wall -o "$tmp_dir/rtl_sim" \
  tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
rtl_output="$(cd "$tmp_dir" && vvp ./rtl_sim)"
printf '%s\n' "$rtl_output"
grep -Fqx 'PASS: 256 vectors checked, 0 errors' <<<"$rtl_output"

echo '==> Confirming the testbench detects an injected full-adder fault'
mkdir -p "$tmp_dir/fault/rtl"
cp rtl/full_adder.v rtl/mult_array.v "$tmp_dir/fault/rtl/"
sed -i 's/assign sum  = a \^ b \^ cin;/assign sum  = a ^ b;/' "$tmp_dir/fault/rtl/full_adder.v"
iverilog -g2012 -Wall -o "$tmp_dir/fault_sim" \
  tb/tb_mult.v "$tmp_dir/fault/rtl/full_adder.v" "$tmp_dir/fault/rtl/mult_array.v"
fault_output="$(cd "$tmp_dir" && vvp ./fault_sim)"
if ! grep -Eq '^FAIL: 256 vectors checked, [1-9][0-9]* errors$' <<<"$fault_output"; then
  printf '%s\n' "$fault_output" >&2
  echo 'FAIL: injected fault was not detected' >&2
  exit 1
fi
grep -E '^FAIL: 256 vectors checked, [1-9][0-9]* errors$' <<<"$fault_output"

echo '==> Checking that the RTL elaborates and synthesizes with Yosys'
yosys -q -p 'read_verilog rtl/full_adder.v rtl/mult_array.v; hierarchy -check -top mult_array; proc; check -assert'

echo '==> Running submission preflight'
./verify_submission.sh

echo 'PASS: all CI checks completed successfully'
