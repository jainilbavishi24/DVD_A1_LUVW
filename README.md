# 4-bit Array Multiplier — Jainil Bavishi, Roll No. 2023102045

This repository contains a registered structural 4-bit unsigned array multiplier, verified across all 256 input combinations and implemented in the SKY130 `sky130_fd_sc_hd` standard-cell library.

## Quick start from a fresh clone

The project includes [`run-osic.sh`](run-osic.sh), a self-contained Docker launcher. It mounts the cloned repository at `/foss/designs/mult4_2023102045`, so all generated files persist on the host after the container exits.

On Ubuntu or Debian, install Docker once and enable access for the current user:

```bash
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
newgrp docker
docker run --rm hello-world
```

Clone the repository, enter it, and start the complete shell environment:

```bash
git clone https://github.com/jainilbavishi24/DVD_A1_LUVW.git
cd DVD_A1_LUVW
chmod +x run-osic.sh run_flow.sh run_full_flow.sh check_fault_injection.sh verify_submission.sh
./run-osic.sh
```

Inside the container, run the verification and implementation flow:

```bash
./run_flow.sh
./check_fault_injection.sh
CLOCK_PERIOD=2.60 sta sta/sta.tcl | tee report/sta_tmin.log
```

`run_flow.sh` selects `sky130A`, runs the exhaustive RTL simulation, Yosys synthesis, exhaustive gate-level simulation and the 10.00 ns OpenSTA run. The current IIC-OSIC image provides the PDK selector as `/foss/tools/sak/sak-pdk-script.sh`; the script handles that version and older images that expose `sak-pdk`.

For a repeatable full flow using the already-closed 6.50 ns configuration, run this inside the container instead:

```bash
./run_full_flow.sh
./verify_submission.sh
```

The required initial LibreLane period was `ceil_to_0.5(1.2 × 2.60 ns) = 3.50 ns`. Timing closure required these seven attempts; each command was run from `pnr/` after changing only `CLOCK_PERIOD` in `config.json`:

```bash
librelane config.json   # 3.50 ns: setup WNS -1.632 ns
librelane config.json   # 4.00 ns: setup WNS -1.632 ns
librelane config.json   # 4.50 ns: setup WNS -1.142 ns
librelane config.json   # 5.00 ns: setup WNS -0.642 ns
librelane config.json   # 5.50 ns: setup WNS -0.142 ns
librelane config.json   # 6.00 ns: setup WNS -0.064 ns
librelane config.json   # 6.50 ns: setup WNS +0.085280 ns; final successful run
```

After the 6.50 ns run, its final artifacts were copied into the submission paths. The completed files are already included in this repository:

```bash
cp runs/RUN_2026-10-03_08-15-52/final/metrics.json metrics.json
cp runs/RUN_2026-10-03_08-15-52/final/gds/mult_array.gds mult_array.gds
cd ..
pdflatex -interaction=nonstopmode -output-directory report report/report.tex
pdflatex -interaction=nonstopmode -output-directory report report/report.tex
./verify_submission.sh
```

`report/report.pdf` is prebuilt for submission. To rebuild it, run the two `pdflatex` commands on a host with TeX Live installed; the source is `report/report.tex`.

## Design notes

- `rtl/full_adder.v` uses continuous `assign` statements only.
- `rtl/mult_array.v` has 16 partial-product AND gates, exactly 12 `full_adder` instances, 8 input flip-flops and 8 output flip-flops.
- The input registers sample at one rising edge and `p` updates at the next rising edge: two clock edges of latency and one result per clock period of throughput.
- The multiplication operator is used only in `tb/tb_mult.v` to calculate the self-checking reference result.

## Results

- RTL simulation: `PASS: 256 vectors checked, 0 errors`.
- Fault injection: `FAIL: 256 vectors checked, 95 errors`; the correct RTL was restored automatically.
- Gate-level simulation: `PASS: 256 vectors checked, 0 errors`.
- Synthesis: 63 cells, 740.7104 µm² total area, 16 flip-flops.
- STA: `T_min = 2.60 ns`, `F_max = 384.615 MHz`.
- Final physical design: 6.50 ns clock, 0.085280 ns setup slack, 0 Magic DRC errors and 0 LVS errors.

`report/report.pdf` contains the completed report, tables, block diagram, waveform example, and the whole-die and close-up layout views. `pnr/runs/` is intentionally excluded from version control because it is a large generated directory.
