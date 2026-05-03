# int8-systolic-mac-array

> **Status:** M1 complete (April 2026)

`int8-systolic-mac-array` is a parameterized output-stationary `INT8` systolic MAC-array implemented in SystemVerilog, targeting `Q/K/V/O` (Query/Key/Value/Output) projections and `FFN` (Feed-Forward Network) layers in transformer attention. \
The design instantiates an `N×N` mesh of MAC PEs fed by a counter-based skew unit, with `INT8` signed inputs accumulating into `INT32`. This implementation of matrix multiplication unit is designed to help maximize the memory access, addressing the bandwidth bottlneck that limits CPU-based matmul for modern LLM workloads.

The verification done is very exhaustive with over 10,000 random matmul tests pass at both 4×4 and 8×8 with zero RTL changes, only parameter changes. The module is validated against a `NumPy` and golden-reference model via `cocotb` + `Verilator`. \
This project is synthesized for the Nexys A7-100T (`xc7a100tcsg324-1`), the 8×8 array uses 64 DSP48E1 units, closing timing at the 100MHz target with a `~3.761ns` positive slack $(Fmax\approx 160MHz)$
This is Milestone-1 of a 7 Milestone project on a Compute-In-Memory transformer accelerator.

## Results

| Metric | Value |
| --- | --- |
| Array Size | 8×8 (parameterized) |
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

![Architecture-Summary](/docs/imgs/architecture_summary.png)

The architecture has three components, **skew unit** that staggers input streams in time, an **$N\times N$ PE mesh** that performs the multiplications and accumulations, and a **controller** that pulses `done` when results are valid.

<!-- Skew Unit summary -->
> ### Skew Unit
>
> The skew unit connects to the input matrices `A` and `B` on the `start` pulse, then emits them one-by-one so that the inputs arrive in a diagonal configuration at the respective PEs in the same cycle. Row `i` arrives at `i` cycles after `start` is pulsed and similarly Column `j` arrives at `j` cycles after `start` is pulsed (assuming square matrix inputs). The total emission spans for `ROW + K - 1` cycles for `A` and `COL + K - 1` cycles for `B`.
<!-- PE Mesh summary -->
> ### $N\times N$ PE Mesh
>
> Each PE follows an **output-stationary** dataflow i.e. the partial sum stays in the PE's accumulator while inputs flow through. Every cycle that PE has `valid_in` high and receives valid data, it computes `acc += (a $\times$ b)`, forwards `a` to the PE on the east (right neighbour) and forwards `b` to the south (bottom neighbour). A `valid_out` signal propagates with the data so that downstream PEs can decide whether their inputs from the skew window are real or invalid.
<!-- Controller Unit summary -->
> ### Controller Unit
>
> The controller counts `COLS + ROWS + K - 2` cycles after `start` is pulsed i.e. the time for the last skewed input to traverse the mesh and update the final PE's accumulator. After this cycle it asserts the `done` signal. Since an output-stationary dataflow is used, the outputs `C[i][j]` are read directly from each PE's accumulator register.

### Serialized Wrapper

The bare array has a parallel-load interface (`A[ROWS][K]` and `B[K][COLS]` updated in one cycle). While for verification this configuration ideally works, during synthesis of this project there were `3077` I/O units detected which clearly exceeded the total number of I/Os of any normal FPGA and is not realistic for system integration. The wrapper module adds a **serial AXI-S** style interface to make the array stream in data serially i.e. one-by-one and result in a more usable implementation as a drop-in IP.

A 6-state FSM (`IDLE` $\rightarrow$ `LOAD_A` $\rightarrow$ `LOAD_B` $\rightarrow$ `DELAY` $\rightarrow$ `COMPUTE` $\rightarrow$ `OUTPUT`) sequences operation:

- **`IDLE`**: IDLE state where the accumulator doesn't process valid data and `in_ready` and `out_ready` signals are set false. No valid computations are done in this state all registers are set to zero
- **`LOAD_A / LOAD_B`**: Inpute matrices are streamed in, one byte per cycle via the `data_in` input and the `valid_in` / `in_ready` handshake.  Internal row / column counters write each byte to its respective positions in the on-chip `A` and `B` buffers.
- **`DELAY`**: 1-cycle delay state that pulses pulses the `start` and `clear` to the bare array exactly once.
- **`COMPUTE`**: The matmul calculations are done in this state. The array runs to completion and signals `done` after the last PE of the matrix has been updated.
- **`OUTPUT`**: The output-stationary results stream out one INT32 value per cycle with `out_valid` and `out_ready` handshake. This operation is throttled by the downstream consumer.

The counters use a 2D row/col interpretation rather than a flat counter with a diviision and modulo. This allows the arbitrary (non-power of 2's) `ROWS`/`COLS`/`K` parameters to synthesize without inferring dividers and which preserves timing margin and keeps the critical path short.

The wrapper is not fully AXI-S compliant as it omits the `TLAST` and uses a simplified port naming, but still demonstrates the overall protocol pattern. A production version would add full AXI-S with double buffering for continuos throughput operation.

## Quick Start

Requires: Python 3.10+, Verilator 5.038+, cocotb 2.0+, Vivado 2025.2 (for synthesis).

```bash
# Clone and set up Python venv
git clone https://github.com/<your-username>/int8-systolic-mac-array.git
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
# to get the timing & util analysis.
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
│
├── docs/                           # Reports, images, and verification logs
│   ├── imgs/                       # Figures used in README/docs
│   │   ├── utilization_table.png
│   │   ├── architecture_summary.png
│   │   └── wns.png
│   ├── verification/               # Saved cocotb run logs
│   │   ├── 4x4.log                 # ROWS=4, COLS=4 output log
│   │   └── 8x8.log                 # ROWS=8, COLS=8 output log
│   ├── pe_spec.md                  # Processing element specification
│   ├── timing.rpt                  # Vivado timing summary
│   └── util.rpt                    # Vivado utilization summary
├── rtl/                            # Synthesizable SystemVerilog RTL
│   ├── wrappers/
│   │   ├── systolic_array_top.sv
│   ├── pe.sv
│   ├── skew.sv
│   └── systolic_array.sv
│
├── syn/                            # Synthesis scripts and generated project files
│   ├── vivado/                     # Vivado project folder
│   ├── constraints.xdc             # Clock and timing constraints
│   └── create_vivado_project.tcl   # Vivado project creation script
├── test/                           # Testbenches and Python-based verification
│   ├── py_tests/
│   │   ├── golden_model.py         # NumPy reference model
│   │   ├── test_array.py           # cocotb random matrix tests
│   │   └── test_top.py             # cocotb tests for wrapper (top) module
│   ├── pe_tb.sv                    # PE unit testbench
│   └── skew_tb.sv                  # Skew unit testbench
├── .gitignore                      # Git ignore rules
├── LICENSE
├── Makefile
└── README.md                       # Project overview and usage
```

## Future Work

- DSP48E1 internal pipelining (AREG/MREG/PREG) for higher Fmax
- M2: BRAM tiled buffers for K > array size
