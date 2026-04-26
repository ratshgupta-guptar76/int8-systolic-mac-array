# int8-systolic-mac-array

> **Status:** M1 complete (April 2026)

`int8-systolic-mac-array` is a parameterized output-stationary `INT8` systolic MAC-array implemented in SystemVerilog, targeting `Q/K/V/O` (Query/Key/Value/Output) projections and `FFN` (Feed-Forward Network) layers in transfromer attention. \
The design instantiates an `N×N` mesh of MAC PEs fed by a counter-based skew unit, with `INT8` signed inputs accumulating into `INT32`. \
The verification done is very exhaustive with over 10,000 random matmul tests pass at both 4×4 and 8×8 with zero RTL changes, only parameter changes. The module is validated against a `NumPy` and golden-reference model via `cocotb` + `Verilator`. \
This project is synthesized for the Nexys A7-100T (`xc7a100tcsg324-1`), the 8×8 array uses 64 DSP48E1 units, closing timing at the 100MHz target with a `~3.761ns` positive slack $(Fmax\approx 160MHz)$
This is Milestone-1 of a 7 Milestone project on a Compute-In-Memory transformer accelerator.

## Results

| Metric | Value |
| --- | --- |
| Array Size | 8×8 (parameterizeds) |
| Data Type | input: INT8 signed, output: INT32 signed accumulator |
| Target FMax | 100MHz |
| Achieved FMax | 160.2MHz (WNS = 3.759ns) |
| DSP48E1 | 64/240 (26.67%) |
| LUTs | 1,562/63,400 (2.46%) |
| Flip-Flops | 4,193/126,800 (3.31%) |
| Latches | 0 |
| Verification | Passes 10,000/10,000 random matmuls |

![Utilization-Table](/docs/imgs/utilization_table.png)
![Timing-Slack](/docs/imgs/wns.png)

## Architecture

    <Architecture Summary>

## Quick Start

Requires: Python 3.10+, Verilator 5.038+, cocotb 2.0+, Vivado 2025.2 (for synthesis).

```bash
# Clone and set up Python venv
git clone <repo>
cd int8-systolic-mac-array
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Run all SV testbenches
make test MODULE=pe
make test MODULE=skew

# Run cocotb random-matmul tests at 4x4 (default)
make cocotb

# Run at 8x8 (edit ROWS/COLS/K in test_array.py and rtl params)
make cocotb


```

```tcl

# NOTE: Implementation will not complete in Vivado but 
# run the following commands in order after synthesis 
# to getthe timing & util analysis.
# Run Synthesis in OOC Mode (-mode out_of_context)

# Reset back to post-synth state
open_run <synth_name>
set_property HD.CLK_SRC BUFGCTRL_X0Y0 [get_ports clk]
opt_design
place_design
route_design
report_timing_summary -file timing.rpt
report_utilization -file util.rpt

```

## Verification

- **PE unit tests** (`test/pe_tb.sv`): directed tests + 65,536-iteration MAC stress test, signed extremes, mid-op reset, clear behavior.
- **Skew unit tests** (`test/skew_tb.sv`): 6 directed tests covering pattern correctness, real-vs-padding zero, input latching, mid-op reset, signed extremes, back-to-back operation.
- **Full-array random tests** (`test/test_array.py`, cocotb + Verilator): 10,000 random INT8 matmuls compared bit-exact against NumPy golden model. Passes at both 4×4 (5.27s) and 8×8 (13.01s) with zero RTL changes.

[4x4.log](/docs/verification/4x4.log) \
[8x8.log](/docs/verification/8x8.log)

## Repo Layout

```py
int8-systolic-mac-array/
|
├── docs/                           # Reports, images, and verification logs
│   ├── imgs/                       # Figures used in README/docs
│   │   ├── utilization_table.png
│   │   ├── architecture.png
│   │   └── wns.png
│   ├── verification/               # Saved cocotb run logs
│   │   ├── 4x4.log                 # ROWS=4, COLS=4 output log
│   │   └── 8x8.log                 # ROWS=8, COLS=8 output log
│   ├── pe_spec.md                  # Processing element specification
│   ├── timing.rpt                  # Vivado timing summary
│   └── util.rpt                    # Vivado utilization summary
├── rtl/                            # Synthesizable SystemVerilog RTL
│   ├── pe.sv
│   ├── skew.sv
│   └── systolic_array.sv
|
├── syn/                            # Synthesis scripts and generated project files
│   ├── vivado/                     # Vivado project folder
│   ├── constraints.xdc             # Clock and timing constraints
│   └── create_vivado_project.tcl   # Vivado project creation script
├── test/                           # Testbenches and Python-based verification
│   ├── py_tests/
│   │   ├── golden_model.py         # NumPy reference model
│   │   └── test_array.py           # cocotb random matrix tests
│   ├── pe_tb.sv                    # PE unit testbench
│   └── skew_tb.sv                  # Skew unit testbench
├── .gitignore                      # Git ignore rules
├── LICENSE
├── Makefile
└── README.md                       # Project overview and usage
```

## Future Work

- DSP48E1 internal pipelining (AREG/MREG/PREG) for higher Fmax
- AXI-stream wrapper for use as drop-in IP
- M2: BRAM tiled buffers for K > array size
