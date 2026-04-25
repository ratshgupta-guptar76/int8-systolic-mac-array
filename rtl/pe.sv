`timescale 1ns/1ps

module pe(
    input logic clk,
    input logic rst_n,
    input logic clear,

    input logic signed [7:0] a_in,
    input logic signed [7:0] b_in,
    input logic valid_in,

    output logic signed [7:0] a_out,
    output logic signed [7:0] b_out,
    output logic signed valid_out,
    output logic signed [31:0] acc
);

   (* use_dsp = "yes" *) logic signed [31:0] prod;
    
    assign prod = (a_in * b_in);
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            a_out <=  8'sd0;
            b_out <=  8'sd0;
            acc   <= 32'sd0;
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
                acc <= 32'sd0;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            valid_out <= 1'b0;
        end else begin
            valid_out <= valid_in;
        end
    end

endmodule
