# 4-bit Array Multiplier — RTL to GDSII on SKY130

| Team member | Roll number |
| --- | --- |
| Jainil Bavishi | 2023102045 |
| Vaibhav Wadhwani | 2023102058 |

This repository contains a registered structural 4-bit unsigned array multiplier, verified exhaustively across all 256 input combinations and taken through synthesis, static timing analysis and place-and-route to GDSII in the SKY130 `sky130_fd_sc_hd` standard-cell library. The completed report is [`report/report.pdf`](report/report.pdf).

All results were produced with the IIC-OSIC-TOOLS image `hpretl/iic-osic-tools:latest` (digest `sha256:306585de35d1…`): Icarus Verilog 14.0 (devel), GTKWave v4.0.0-prealpha, Yosys 0.70, OpenSTA 3.1.0, LibreLane 3.1.0.dev3, KLayout 0.30.12. Older images give slightly different synthesis results and timing.

## Environment

On Ubuntu, Debian or WSL 2, install Docker once and let the current user use it:

```bash
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
newgrp docker            # or restart the shell / `wsl --shutdown` on Windows
docker run --rm hello-world
```

Clone the repository and start a shell in the tools container. [`run-osic.sh`](run-osic.sh) mounts the repository at `/foss/designs/mult4_2023102045`, so every generated file stays on the host:

```bash
git clone https://github.com/jainilbavishi24/DVD_A1_LUVW.git
cd DVD_A1_LUVW
./run-osic.sh
```

All commands below are run inside the container from the repository root. Select the SKY130 PDK first. Current images provide the selector as a sourceable script; older images provide `sak-pdk`:

```bash
source /foss/tools/sak/sak-pdk-script.sh sky130A    # older images: sak-pdk sky130A
echo $PDK_ROOT $PDK                                   # /foss/pdks sky130A
```

## Commands run, in order

### Part A — RTL design and verification

```bash
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim | tee report/rtl_simulation.log          # PASS: 256 vectors checked, 0 errors
gtkwave mult.vcd                                  # A=10, B=7 at 3360-3375 ns
```

Fault-injection check: temporarily change `sum` to `a ^ b`, rerun, confirm FAIL, then restore the RTL. [`check_fault_injection.sh`](check_fault_injection.sh) does exactly this and restores the file automatically:

```bash
./check_fault_injection.sh                        # FAIL: 256 vectors checked, 95 errors
```

### Part B — Logic synthesis

```bash
yosys -c synth/synth.tcl | tee report/synthesis.log
CELLS=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls \
  tb/tb_mult.v $CELLS/primitives.v $CELLS/sky130_fd_sc_hd.v synth/mult_array_netlist.v
vvp gls | tee report/gls_simulation.log           # PASS: 256 vectors checked, 0 errors
```

### Part C — Static timing analysis

[`sta/sta.tcl`](sta/sta.tcl) uses a 10 ns clock unless `CLOCK_PERIOD` is set in the environment.

```bash
sta sta/sta.tcl | tee report/sta_10ns.log                         # worst slack 7.21 ns
CLOCK_PERIOD=2.79 sta sta/sta.tcl | tee report/sta_tmin.log       # worst slack 0.00 ns (+0.003)
```

T_min = 10.00 − 7.21 = 2.79 ns, so F_max = 358.42 MHz. `sta/mult_array_timing.rpt` holds the critical-path report at 2.79 ns.

[`run_flow.sh`](run_flow.sh) runs the PDK selection and every command in Parts A–C (up to the 10 ns STA) in one go.

### Part D — Physical design

The first LibreLane period is ceil_0.5(1.2 × 2.79 ns = 3.348 ns) = 3.50 ns. Each attempt was run from `pnr/` after changing only `CLOCK_PERIOD` in [`pnr/config.json`](pnr/config.json); the period was increased by 0.5 ns after every run with setup violations.

```bash
cd pnr
librelane config.json   # 3.50 ns: setup WNS -2.546 ns
librelane config.json   # 4.00 ns: setup WNS -2.027 ns
librelane config.json   # 4.50 ns: setup WNS -1.527 ns
librelane config.json   # 5.00 ns: setup WNS -1.027 ns
librelane config.json   # 5.50 ns: setup WNS -0.527 ns
librelane config.json   # 6.00 ns: setup WNS -0.037 ns
librelane config.json   # 6.50 ns: setup WNS -0.205 ns
librelane config.json   # 7.00 ns: setup WNS -0.116 ns
librelane config.json   # 7.50 ns: setup WNS -0.138 ns
librelane config.json   # 8.00 ns: setup WNS +0.362 ns; final successful run
```

The final run's artifacts were copied into the submission paths, the layout screenshots were rendered with KLayout, and the report was rebuilt:

```bash
cp runs/RUN_2026-10-17_20-33-54/final/metrics.json metrics.json
cp runs/RUN_2026-10-17_20-33-54/final/gds/mult_array.gds mult_array.gds
cd ..
klayout -zz -r render_layout.py                   # report/layout_whole_die.png, report/layout_zoomed.png
./verify_submission.sh
```

The report source is [`report/report.tex`](report/report.tex). The container has no LaTeX, so it was built on the host with [Tectonic](https://tectonic-typesetting.github.io/) (`pdflatex` twice works equally well):

```bash
tectonic report/report.tex                        # or: pdflatex -output-directory report report/report.tex (twice)
```

[`run_full_flow.sh`](run_full_flow.sh) repeats Parts A–D using the period currently in `pnr/config.json` and copies the final artifacts; [`verify_submission.sh`](verify_submission.sh) checks that every deliverable is present and passing.

## Design notes

- `rtl/full_adder.v` uses continuous `assign` statements only.
- `rtl/mult_array.v` has 16 partial-product AND gates, exactly 12 `full_adder` instances, 8 input flip-flops and 8 output flip-flops, all with asynchronous active-low reset. The `*` operator is not used.
- Inputs are captured at one rising edge and `p` updates at the next: 2 cycles of latency and one result per clock.
- `tb/tb_mult.v` uses `*` only for the reference result, and samples `p` on the falling edge after the capture edge so RTL and gate-level runs are free of clock-to-Q races.
- `pnr/runs/` is excluded from version control because it is a large generated directory.

## Results

| Stage | Result |
| --- | --- |
| RTL simulation | `PASS: 256 vectors checked, 0 errors` |
| Fault injection | `FAIL: 256 vectors checked, 95 errors` (RTL restored) |
| Synthesis | 61 cells, 756.976 µm², 16 `dfrtp_1` flip-flops (52.89% of area) |
| Gate-level simulation | `PASS: 256 vectors checked, 0 errors` |
| STA (tt_025C_1v80) | WNS at 10 ns = 7.21 ns, T_min = 2.79 ns, F_max = 358.42 MHz |
| Place and route | 8.00 ns clock after 10 runs, setup slack 0.3618 ns, post-route F_max 130.92 MHz |
| Signoff | 0 Magic DRC errors, 0 KLayout DRC errors, 0 LVS errors |
