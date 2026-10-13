# Digital VLSI Assignment: 4-bit Array Multiplier

**Student:** Jainil Bavishi
**Roll number:** 2023102045
**Technology:** SkyWater SKY130, `sky130_fd_sc_hd`

## Design

The design is a registered 4-bit by 4-bit unsigned array multiplier. Four AND-gate rows form the partial products. The first row supplies `p[0]`; each of the following three rows uses four full adders. Thus the array has 16 AND gates and 12 full adders. Four input flip-flops register each operand and eight output flip-flops register the product. A value applied before edge 1 is captured into the input registers on edge 1 and appears at `p` on edge 2.

## Example multiplication

The final roll-number digit is 5, so the required example is `A = 5 + 5 = 10` and `B = 7`.

```
      1010   (10)
    x 0111   (7)
    ------
      1010
     10100
    101000
   0000000
    ------
   1000110   (70)
```

## Verification

The self-checking testbench applies every one of the 256 possible `(a,b)` combinations. It holds asynchronous reset low for two rising edges, waits for the two-edge register latency, compares `p` against the testbench reference multiplication, reports every mismatch, and emits `PASS: 256 vectors checked, 0 errors` only when all cases match. It also writes `mult.vcd` for waveform inspection.

The final measured synthesis, timing and place-and-route results are inserted below after running the reproducible flow.

## Part B — Logic synthesis

| Metric | Measured value |
| --- | --- |
| Total number of cells | 63 cells |
| Number of flip-flops | 16 `sky130_fd_sc_hd__dfrtp_1` cells |
| Total cell area (µm²) | 740.7104 µm² |
| Flip-flop area (µm²) | 400.3840 µm² |
| Flip-flop area (% of total) | 54.05% |
| Three most-used cell types | `dfrtp_1`: 16; `nand2_1`: 8; `a21oi_1`: 6 |
| Gate-level simulation | PASS: 256 vectors checked, 0 errors |

The logic-cell count is not simply 28 because each full-adder Boolean expression maps to several library gates and synthesis can optimize or decompose logic to match available SKY130 cells. The 16 registers are separate sequential library cells and are included in total cell count and area.

## Part C — Static timing analysis

| Metric | Measured value |
| --- | --- |
| Worst slack at 10 ns (ns) | 7.40 ns |
| Minimum period, T_min (ns) | 2.60 ns |
| F_max (MHz) | 384.615 MHz |
| Slack at T_min (ns) | -0.004 ns |
| Critical-path start point | `_095_/Q` input-register output |
| Critical-path end point | `_092_/D` output-register input |
| Cells on the critical path | 10 cells including endpoint flip-flops |
| Latency (ns) | 5.20 ns |
| Throughput (million results/s) | 384.615 million results/s |

The expected critical path starts at an operand register and ends at a product register. It crosses partial-product logic and the ripple-carry network. For an N-bit array, the estimate is approximately 2N full-adder delays, or about eight for N = 4; mapped standard-cell paths express this with multiple gates per full-adder stage.

## Part D — Physical design

| Metric | Measured value |
| --- | --- |
| CLOCK_PERIOD used (ns) | 6.50 ns |
| Number of runs needed | 7 runs |
| Core area (µm²) | 17,759.5 µm² |
| Cells after synthesis | 63 cells |
| Cells after place and route | 1,901 instances |
| Added cell kinds | 1,566 filler cells; 245 tap cells; 19 timing-repair buffers; 3 clock buffers |
| Wirelength (µm) | 2,405 µm |
| Setup slack (ns) | 0.085280 ns |
| Post-route F_max (MHz) | 155.891 MHz |
| F_max from Part C (MHz) | 384.615 MHz |
| DRC errors | 0 errors |
| LVS errors | 0 errors |

Post-route frequency is normally lower than pre-layout frequency because placement and routing add wire delay and parasitics. The physical flow also adds clock buffers to control clock insertion delay, filler cells to complete legal placement rows, tap cells to protect against latch-up, and decoupling cells to stabilize the local supply.

DRC verifies that the physical geometry follows manufacturing rules such as width, spacing and enclosure. LVS compares the extracted physical netlist with the intended schematic/netlist. Both must pass because a layout can obey geometry rules yet implement incorrect connectivity, or have correct connectivity while violating a process rule.

## Scaling to an 8-bit multiplier

For N bits, the array uses N² AND gates and N(N−1) full adders. At N = 8 this is 64 AND gates and 56 full adders, compared with 16 and 12 at N = 4. The longest path estimate grows from 2 × 4 = 8 full-adder delays to 2 × 8 = 16 full-adder delays, so delay roughly doubles and maximum frequency roughly halves before layout effects.
