#!/usr/bin/env bash
# Prove that tb_mult detects a broken full-adder sum expression, then restore RTL.
set -euo pipefail

mkdir -p report
backup="rtl/full_adder.v.fault-test-backup"
cp rtl/full_adder.v "$backup"
restore() {
  mv "$backup" rtl/full_adder.v
}
trap restore EXIT

sed -i 's/assign sum  = a \^ b \^ cin;/assign sum  = a ^ b;/' rtl/full_adder.v
iverilog -g2012 -o sim_fault tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim_fault | tee report/fault_injection.log

if ! grep -q '^FAIL: 256 vectors checked,' report/fault_injection.log; then
  echo "Fault-injection test did not report FAIL." >&2
  exit 1
fi
rm -f sim_fault
