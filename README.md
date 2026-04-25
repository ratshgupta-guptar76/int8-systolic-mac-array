# int8-systolic-mac-array

## Deliverables (repo contents)

- Parameterized PE RTL (SV): multiply-accumulate, configurable bitwidth
- 8x8 (or 16x8) systolic array top-level with AXI-stream handshaking
- Verilator testbench: random INT8 inputs verified against NumPy reference
- Vivado utilization report: DSP slice count, LUT count, Fmax
- README with architecture diagram and benchmark table

## What it is

In this repo I will make a Systollic MAC Array based on an `int8` datawidth. Systollic Array based calculations is a processing method of data transfer used by Deep Learning models to reduce Ram - CPU data transfer bottlenecks.

It can be seen in the structure of the Google TPU due to its ability to handle large-scale matrix multiplication. It is widely used for training AI models.

### Benefits

The benefit of using a systollic array is that in a Traditional CPU for one memory access, one computation is done. Whereas using a Systollic MAC Array processing algorithm, for each memory call we can have multiple computes. This significantly reduces the memory bottleneck. It helps acheive massive parallelism.

## Design Parameters / Architecture

    Array Size:         8x8 (parameterized, tested at 4x4 and 8x8)
    Data Type:          INT8 signed inputs, INT32 signed accumulator
    Inner dimension:    K=8 (number of multiply-accumulate cycles per output) 
    Throughput:         One 8x8 output matrix every K + N - 1 = 15 cycles (steady state)
    DSP48E1 slices:     ~64 (target, 1 per PE on FPGA-board)
    Target Fmax:        100Mhz
    LUT utilization:    <X% Y/Z> after synthesis
    Test coverage:      10,000 random INT8 matrix pairs, bit-accurate vs NumPy

![Vivado-PE-TimingAnalysis](/docs//imgs/vivado_PE.png)
![Vivado-PE-Table](/docs/imgs/vivado_PE_UtilizationTable.png)
