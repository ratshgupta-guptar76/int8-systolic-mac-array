# Processing Element Specifications

Module: pe

## Inputs

$\quad$ clk, rst_n \
$\quad$ `a_in[7:0]` signed INT8, flows $West \rightarrow East$ \
$\quad$ `b_in[7:0]` signed INT8, flows $North \rightarrow South$ \
$\quad$ `valid_in`

## Outputs

$\quad$ `a_out[7:0]` registered copy of $a_{in}$ (1 cycle delay) \
$\quad$ `b_out[7:0]` registered copy of $b_{in}$ (1 cycle delay) \
$\quad$ `acc[31:0]` $\sum$ $A_{i,k}\times $B_{k,j}$$ (registered) \

## Behaviour

$\hspace{0.5em}$ On posedge `clk` (when $valid_{in}$ is high): \
$\quad$ a_out <= a_in \
$\quad$ b_out <= b_in \
$\quad$ c_out <= (a_in * b_in) + c_in \
$\hspace{0.5em}$ On `rst_n` low: \
$\quad$ All outputs = 0 \

## Latency: 1 clock cycle

Accumulator width: INT32 prevents overflow for up to 256 INT8 x INT8 accumulations  (worst case: 128 x 128 x 256 = 4,194,304; fits in 32 bits with sign)

## Design Decisions: Single always-visible wire to accumulator

- There were two ways of accessing the accumulator output through the PEs: draining out the accums and always-visible wires.

### 1. Draining out the accums

| Benefits | Drawbacks |
| --- | --- |
| Reduces memory area and keeps the design more compact. | Requires `N-1` extra clock cycles and increases latency significantly. |

### 2. Always-visible wires

| Benefits | Drawbacks |
| --- | --- |
| Heavily reduces complexity and makes reading accumulator outputs much faster. | Increases memory area used. Although Not significant enough for our design. |
