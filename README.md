# int8-systolic-mac-array

    <SUMMARY>

## Results

| Metric | Value |
| --- | --- |
| Array Size | 8×8 (parameterizeds) |
| Data Type | input: INT8 signed, output: INT32 signed accumulator |
| Target FMax | 100MHz |
| Acheived FMax | 160.2mHz (WNS = 3.759ns) |
| DSP48E1 | 64/240 (26.67%) |
| LUTs | 1,562/63,400 (2.46%) |
| Flip-Flops | 4,193/126,000 (3.31%) |
| Latches | 0 |
| Verification | Passes 10,000/10,000 TestCases |

![Utilization-Table](/docs/imgs/utilization_table.png)
![Timing-Slack](/docs/imgs/wns.png)

## Archtiecture

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

# Synthesis (Vivado required)
cd syn && vivado -mode batch -source ooc_flow.tcl

```

## Repo Layout

```
int8-systolic-mac-array/
|
├── docs/                           # Reports, images, and verification logs
│   ├── imgs/                       # Figures used in README/docs
│   │   ├── utilization_table.png
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
│   │   ├── __pycache__/
│   │   ├── golden_model.py         # NumPy reference model
│   │   └── test_array.py           # cocotb random matrix tests
│   ├── pe_tb.sv                    # PE unit testbench
│   └── skew_tb.sv                  # Skew unit testbench
├── .gitignore                      # Git ignore rules
├── LICENSE
├── Makefile
└── README.md                       # Project overview and usage
```

## Verification

- **PE unit tests** (`tb/pe_tb.sv`): directed tests + 65,536-iteration MAC stress test, signed extremes, mid-op reset, clear behavior.
- **Skew unit tests** (`tb/skew_tb.sv`): 6 directed tests covering pattern correctness, real-vs-padding zero, input latching, mid-op reset, signed extremes, back-to-back operation.
- **Full-array random tests** (`tb/test_array.py`, cocotb + Verilator): 10,000 random INT8 matmuls compared bit-exact against NumPy golden model. Passes at both 4×4 (5.27s) and 8×8 (13.01s) with zero RTL changes — pure parameter swap.

[4x4.log](/docs/verification/4x4.log) \
[8x8.log](/docs/verification/8x8.log)

### Benefits

The benefit of using a systollic array is that in a Traditional CPU for one memory access, one computation is done. Whereas using a Systollic MAC Array processing algorithm, for each memory call we can have multiple computes. This significantly reduces the memory bottleneck. It helps acheive massive parallelism.

<!-- ## Design Parameters / Architecture

    Array Size:         8x8 (parameterized, tested at 4x4 and 8x8)
    Data Type:          INT8 signed inputs, INT32 signed accumulator
    Inner dimension:    K=8 (number of multiply-accumulate cycles per output) 
    Throughput:         One 8x8 output matrix every K + N - 1 = 15 cycles (steady state)
    DSP48E1 slices:     ~64 (target, 1 per PE on FPGA-board)
    Target Fmax:        100Mhz
    LUT utilization:    <X% Y/Z> after synthesis
    Test coverage:      10,000 random INT8 matrix pairs, bit-accurate vs NumPy -->
<!-- 
![Vivado-PE-TimingAnalysis](/docs//imgs/vivado_PE.png)
![Vivado-PE-Table](/docs/imgs/vivado_PE_UtilizationTable.png) -->
