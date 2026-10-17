# Digital VLSI Assignment: 4-bit Array Multiplier

**Team:** Jainil Bavishi (2023102045), Vaibhav Wadhwani (2023102058)
**Technology:** SkyWater SKY130, `sky130_fd_sc_hd`

This is a Markdown summary of [`report.pdf`](report.pdf) (source: [`report.tex`](report.tex)), which has the figures and full answers. All numbers come from the current IIC-OSIC-TOOLS image (Yosys 0.70, OpenSTA 3.1.0, LibreLane 3.1.0.dev3).

## Part A — Design and verification

Registered 4 × 4 unsigned array multiplier: 16 AND gates, 12 `full_adder` instances, 8 input and 8 output flip-flops with asynchronous active-low reset. Latency 2 cycles, throughput 1 result per cycle.

- RTL simulation: `PASS: 256 vectors checked, 0 errors`
- Fault injection (`sum = a ^ b`): `FAIL: 256 vectors checked, 95 errors`, RTL restored
- Example (Jainil Bavishi's roll number 2023102045, last digit 5): A = 5 + 5 = 10, B = 7

```
        1 0 1 0      A = 10
      x 0 1 1 1      B = 7
   ---------------
        1 0 1 0      pp0 = A AND b0 (b0 = 1)
      1 0 1 0        pp1 = A AND b1 (b1 = 1), shifted 1
    1 0 1 0          pp2 = A AND b2 (b2 = 1), shifted 2
  0 0 0 0            pp3 = A AND b3 (b3 = 0), shifted 3
   ---------------
0 1 0 0 0 1 1 0      P = 70
```

In the waveform the operands are applied at 3360 ns, captured at edge 1 (3365 ns), and `p = 70` is captured at edge 2 (3375 ns).

## Part B — Logic synthesis

| Metric | Value |
| --- | --- |
| Total number of cells | 61 |
| Number of flip-flops | 16 `sky130_fd_sc_hd__dfrtp_1` |
| Total cell area | 756.976 µm² |
| Flip-flop area | 16 × 25.024 = 400.384 µm² |
| Flip-flop area (% of total) | 52.89% |
| Three most-used cell types | `dfrtp_1`: 16; `nand2_1`: 7; `maj3_1` and `and2_0`: 4 each |
| Netlist simulation | `PASS: 256 vectors checked, 0 errors` |

## Part C — Static timing analysis (tt_025C_1v80)

| Metric | Value |
| --- | --- |
| Worst slack at T = 10 ns | 7.21 ns |
| T_min | 2.79 ns |
| F_max | 358.42 MHz |
| Slack at T = T_min | +0.003 ns |
| Critical-path start point | `_91_` (input register `a_reg[1]`) |
| Critical-path end point | `_88_/D` (output register `p[6]`, sum of `fa_r3_3`) |
| Cells on the critical path | 10 (8 combinational + 2 flip-flops) |
| Latency = 2 × T_min | 5.58 ns |
| Throughput | 358.42 million results/s |

Path: `dfrtp_1` → `clkinv_1` → `o311ai_0` → `a21oi_1` → `maj3_1` → `xnor3_1` → `maj3_1` → `maj3_1` → `xor3_1` → `dfrtp_1`. Five combinational cells are full-adder carry (`maj3`) and sum (`xnor3`, `xor3`) functions; the first three are AND gates merged with the simplified row-1 adder.

## Part D — Physical design

The initial period is ceil_0.5(1.2 × 2.79) = 3.50 ns. Every run had 0 DRC and 0 LVS errors, and the limiting corner was always `max_ss_100C_1v60`.

| Run | CLOCK_PERIOD (ns) | WNS, all corners (ns) | WNS, nom tt (ns) | Setup violations |
| --- | --- | --- | --- | --- |
| 1 | 3.50 | −2.546 | +0.431 | 15 |
| 2 | 4.00 | −2.027 | +0.929 | 15 |
| 3 | 4.50 | −1.527 | +1.429 | 12 |
| 4 | 5.00 | −1.027 | +1.929 | 9 |
| 5 | 5.50 | −0.527 | +2.429 | 9 |
| 6 | 6.00 | −0.037 | +2.911 | 1 |
| 7 | 6.50 | −0.205 | +3.111 | 6 |
| 8 | 7.00 | −0.116 | +3.526 | 5 |
| 9 | 7.50 | −0.138 | +3.722 | 5 |
| 10 | 8.00 | +0.362 | +4.222 | 0 |

| Metric | Value |
| --- | --- |
| CLOCK_PERIOD used | 8.00 ns |
| Number of runs needed | 10 |
| Core area / die area | 17,759.5 µm² / 22,500 µm² |
| Cells after synthesis | 61 |
| Cells after place and route | 1,884 instances (86 excluding fillers and taps) |
| Kinds of cells added | 1,299 decap + 254 filler cells; 245 tap cells; 21 timing-repair buffers; 3 clock buffers |
| Wirelength | 2,518 µm |
| Setup slack | 0.3618 ns |
| Post-route F_max = 1000/(T − slack) | 130.92 MHz |
| F_max from Part C | 358.42 MHz |
| DRC errors (Magic / KLayout) | 0 / 0 |
| LVS errors | 0 |

## Scaling to an 8-bit multiplier

N² AND gates and N(N−1) full adders: 64 and 56 at N = 8, against 16 and 12 at N = 4. The critical path grows from about 8 to about 16 full-adder delays. Scaling the measured path (2.254 ns of logic doubles to about 4.51 ns, plus 0.398 ns clock-to-Q and 0.135 ns setup) gives T_min ≈ 5.04 ns, or F_max ≈ 198 MHz before layout effects.
