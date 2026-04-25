`timescale 1ns/1ps

module systolic_array #(
    parameter int ROWS = 8,
    parameter int COLS = 8,
    parameter int K = 8
) (
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic clear,

    input var logic signed [7:0] A [ROWS][K],
    input var logic signed [7:0] B [K][COLS],

    output logic signed [31:0] C [ROWS][COLS],
    output logic skew_done,
    output logic done
);

    localparam int TOTAL_CYCLES = ROWS + COLS + K - 2;

    logic signed [7:0] SKEW_A [ROWS];
    logic signed [7:0] SKEW_B [COLS];
    logic              valA [ROWS];
    logic              valB [COLS];

    logic signed [7:0] pe_a [ROWS][COLS];
    logic signed [7:0] pe_b [ROWS][COLS];

    logic valOut [ROWS][COLS];

    // logic skew_done;

    skew #(
        .ROWS(ROWS),
        .COLS(COLS),
        .K(K)
    ) skew_UUT (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),

        .A_MAT(A),
        .B_MAT(B),
        
        .SKEWED_A(SKEW_A),
        .SKEWED_B(SKEW_B),
        .valid_a(valA),
        .valid_b(valB),
        .done(skew_done)
    );

    genvar r;
    genvar c;
    generate
        for (r = 0; r < ROWS; r++) begin : GEN_ROWS
            for (c = 0; c < COLS; c++) begin : GEN_COLS
                pe pe_UUT (
                    .clk(clk),
                    .rst_n(rst_n),
                    .clear(clear),
                    .a_in((c == 0) ? SKEW_A[r] : pe_a[r][c-1]),
                    .b_in((r == 0) ? SKEW_B[c] : pe_b[r-1][c]),
                    .valid_in(
                        (c == 0 && r == 0)  ? valA[r] & valB[c] :
                        (c==0)              ? valA[r] & valOut[r-1][c] : 
                        (r==0)              ? valOut[r][c-1] & valB[c] :
                                              valOut[r][c-1] & valOut[r-1][c]
                    ),
                    .a_out(pe_a[r][c]),
                    .b_out(pe_b[r][c]),
                    .valid_out(valOut[r][c]),
                    .acc(C[r][c])
                );
            end
        end
    endgenerate

    logic [7:0] cycles;
    logic running;

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            running <= 1'b0;
            done <= 1'b0;
            cycles <= 8'd0;
        end else begin
            done <= 1'b0;
            if (start) begin
                running <= 1'b1;
                cycles <= 8'd0;
            end
            if (running) begin
                cycles <= cycles + 1'd1;
                if (int'(cycles) == TOTAL_CYCLES - 1) begin
                    running <= 1'b0;
                    done <= 1'b1;
                end
            end
        end
    end

endmodule
