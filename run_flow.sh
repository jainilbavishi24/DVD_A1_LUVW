#!/usr/bin/env bash
# Run inside IIC-OSIC-TOOLS from /foss/designs/mult4_2023102045.
set -euo pipefail

# The committed logs, netlist, GDS and report numbers come from image 2026.10
# (pinned in run-osic.sh). Other images still pass, but with different numbers.
if [[ "${IIC_OSIC_TOOLS_VERSION:-unknown}" != 2026.10 ]]; then
  echo "WARNING: running in IIC-OSIC-TOOLS ${IIC_OSIC_TOOLS_VERSION:-unknown}, not 2026.10." >&2
  echo "         Cell counts and timing will not match report/report.tex." >&2
fi

# IIC-OSIC-TOOLS 2026 exposes the selector as a sourceable script; older
# images provide the compatible sak-pdk command.
if command -v sak-pdk >/dev/null 2>&1; then
  sak-pdk sky130A
else
  # The current helper finishes with optional-variable tests that return 1.
  # Run it without strict modes, then restore the runner's error checking.
  set +eu
  source /foss/tools/sak/sak-pdk-script.sh sky130A || true
  set -eu
fi
cells="$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog"

mkdir -p report
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim | tee report/rtl_simulation.log

yosys -c synth/synth.tcl | tee report/synthesis.log
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls \
  tb/tb_mult.v "$cells/primitives.v" "$cells/sky130_fd_sc_hd.v" synth/mult_array_netlist.v
vvp gls | tee report/gls_simulation.log

sta sta/sta.tcl | tee report/sta_10ns.log

echo "Flow stages through 10 ns STA are complete. Set pnr CLOCK_PERIOD from measured T_min before running LibreLane."
