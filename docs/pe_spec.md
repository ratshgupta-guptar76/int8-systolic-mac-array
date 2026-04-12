# Processing Element Specifications

Module: pe

Inputs: \
$\quad$ clk, rst_n \
$\quad$ `a_in[7:0]` signed INT8, flows $West \rightarrow East$ \
$\quad$ `b_in[7:0]` signed INT8, flows $North \rightarrow South$ \
$\quad$ `c_in[7:0]` signed INT32, partial sum from above (or 0 for top row) \
$\quad$ `valid_in`

Outputs: \
$\quad$ `a_out[7:0]` registered copy of $a_{in}$ (1 cycle delay) \
$\quad$ `b_out[7:0]` registered copy of $b_{in}$ (1 cycle delay) \
$\quad$ `c_out[7:0]` $(a_{in} * b_{in}) + c_{in}$ (registered) \
$\quad$ `valid_out[7:0]` registered copy of $valid_{in}$ (1 cycle delay) \

Behaviour: \
$\hspace{0.5em}$ On posedge `clk` (when $valid_{in}$ is high): \
$\quad$ a_out <= a_in \
$\quad$ b_out <= b_in \
$\quad$ c_out <= (a_in * b_in) + c_in \
$\hspace{0.5em}$ On `rst_n` low: \
$\quad$ All outputs = 0 \

Latency: 1 clock cycle \
Accumulator width: INT32 prevents overflow for up to 256 INT8 x INT8 accumulations  (worst case: 128 x 128 x 256 = 4,194,304; fits in 32 bits with sign)
