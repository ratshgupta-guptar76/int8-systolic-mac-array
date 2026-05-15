`timescale 1ns/1ps

module pe #(
    parameter int DW = 8,
    parameter int K = 8
) (
    input logic clk,
    input logic rst_n,
    input logic clear,

    input logic signed [DW-1:0] a_in,
    input logic signed [DW-1:0] b_in,
    input logic valid_in,

    output logic signed [DW-1:0] a_out,
    output logic signed [DW-1:0] b_out,
    output logic signed valid_out,
    output logic signed [ACC_DW-1:0] acc
);

    localparam int ACC_DW = 2*DW + $clog2(K);

   (* use_dsp = "yes" *) logic signed [ACC_DW-1:0] prod;
    
    assign prod = (a_in * b_in);
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            a_out <=  '0;
            b_out <=  '0;
            acc   <=  '0;
        end else begin
            if (valid_in) begin
                a_out <= a_in;
                b_out <= b_in;
                acc <= prod + acc;
            end else begin
                a_out <= a_out;
                b_out <= b_out;
                acc <= acc;
            end
            if (clear) begin
                acc <= '0;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            valid_out <= '0;
        end else begin
            valid_out <= valid_in;
        end
    end

endmodule
