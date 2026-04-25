# Processing Element Specifications

Module: pe

## Inputs

$\quad$ `clk`, `rst_n`, `clear` \
$\quad$ `a_in[7:0]` signed INT8, flows $West \rightarrow East$ \
$\quad$ `b_in[7:0]` signed INT8, flows $North \rightarrow South$ \
$\quad$ `valid_in`

## Outputs

$\quad$ `a_out[7:0]` registered copy of $a_{in}$ (1 cycle delay) \
$\quad$ `b_out[7:0]` registered copy of $b_{in}$ (1 cycle delay) \
$\quad$ `acc[31:0]` $\sum$ $A_{i,k}\times B_{k,j}$ (registered) \
$\quad$ `valid_out`

## Behaviour

**System Reset** (`rst_n` low on any clock edge):

- `a_out` <= 8'sd0
- `b_out` <= 8'sd0
- `acc` <= 32'sd0
- `valid_out` <= 1'b0

**Normal Operation** (`rst_n` high):
<!-- markdownlint-disable MD033 -->
| Condition                   | Action                                                                              |
|-----------------------------|-------------------------------------------------------------------------------------|
| `valid_in` = 1, `clear` = 0 | `a_out` <= `a_in`; <br> `b_out` <= `b_in`; <br> `acc` <= (`a_in` × `b_in`) + `acc`; |
| `valid_in` = 1, `clear` = 1 | `a_out` <= `a_in`; <br> `b_out` <= `b_in`; <br> `acc` <= 32'sd0;                    |
| `valid_in` = 0, `clear` = 0 | `a_out` <= `a_out`; <br> `b_out` <= `b_out`; <br> `acc` <= `acc` (hold state);      |
| `valid_in` = 0, `clear` = 1 | `a_out` <= `a_out`; <br> `b_out` <= `b_out`; <br> `acc` <= 32'sd0;                  |
<!-- markdownlint-enable MD033 -->
**Signal Semantics:**

- `clear`: Resets the accumulator between matrix multiplications (does not affect pipeline registers)
- `valid_in`: Controls whether new data is latched into the PE on the clock edge

## Latency

- **Pipeline delay**: 2 clock cycles from input to output
  - Cycle 1: `a_in`, `b_in`, `valid_in` latched into `a_out`, `b_out`, `valid_out` & multiplication computed
  - Cycle 2: Accumulation result available on `acc`
- **Output registers**: `a_out`, `b_out`, `acc`, `valid_out` are all registered outputs

## Accumulator Capacity

INT32 accumulator width prevents overflow for up to 256 INT8 × INT8 accumulations:

- Worst case: |−128| × |−128| × 256 = 4,194,304
- INT32 range: −2,147,483,648 to 2,147,483,647

## Design Decisions: Single always-visible wire to accumulator

There were two ways of accessing the accumulator output through the PEs: draining out the accums and always-visible wires.

### 1. Draining out the accums

| Benefits | Drawbacks |
| --- | --- |
| Reduces memory area and keeps the design more compact. | Requires `N-1` extra clock cycles and increases latency significantly. |

### 2. Always-visible wires

| Benefits | Drawbacks |
| --- | --- |
| Heavily reduces complexity and makes reading accumulator outputs much faster. | Increases memory area used. Although Not significant enough for our design. |
