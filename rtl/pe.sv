module pe(
    input logic clk,
    input logic rst_n,

    input logic signed [7:0] a_in,
    input logic signed [7:0] b_in,
    input logic signed [31:0] c_in,
    input logic valid_in,

    output logic signed [7:0] a_out,
    output logic signed [7:0] b_out,
    output logic signed [31:0] c_out,
    output logic valid_out
);
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            a_out <= 8'sd0;
            b_out <= 8'sd0;
            c_out <= 32'sd0;
            valid_out <= 1'b0;
        end else begin
            if (valid_in) begin
                a_out <= a_in;
                b_out <= b_in;
                c_out <= (a_in * b_in) + c_in;
                valid_out <= 1'b1;
            end else begin
                a_out <= a_out;
                b_out <= b_out;
                c_out <= c_out;
                valid_out <= 1'b0;
            end
        end
    end

endmodule