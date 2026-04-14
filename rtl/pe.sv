`timescale 1ns/1ps

module pe(
    input logic clk,
    input logic rst_n,

    input logic signed [7:0] a_in,
    input logic signed [7:0] b_in,
    input logic valid_in,

    output logic signed [7:0] a_out,
    output logic signed [7:0] b_out,
    output logic signed [31:0] acc
);
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            a_out <=  8'sd0;
            b_out <=  8'sd0;
            acc   <= 32'sd0;
        end else begin
            if (valid_in) begin
                a_out <= a_in;
                b_out <= b_in;
                acc <= (a_in * b_in) + acc;
            end else begin
                a_out <= a_out;
                b_out <= b_out;
                acc <= acc;
            end
        end
    end

endmodule
