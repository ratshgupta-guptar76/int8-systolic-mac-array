`timescale 1ns/1ps

module pe_tb;

    logic clk;
    logic rst_n;

    logic signed [7:0] a_in;
    logic signed [7:0] b_in;
    logic signed [31:0] c_in;
    logic valid_in;

    logic signed [7:0] a_out;
    logic signed [7:0] b_out;
    logic signed [31:0] c_out;
    logic valid_out;

    // 1. Clock generation - 100MHz clock
    initial
        clk = 0;

    always #5 clk = ~clk; // Toggle every 5ns - 10ns period for 100MHz


    // 2. Instantiate the PE module
    pe DUT (
        .clk(clk),
        .rst_n(rst_n),

        .a_in(a_in),
        .b_in(b_in),
        .c_in(c_in),
        .valid_in(valid_in),

        .a_out(a_out),
        .b_out(b_out),
        .c_out(c_out),
        .valid_out(valid_out)
    );

    // 3. Test variables
    int passed = 0;
    int failed = 0;
    int total_tests = 0;

    // 4. Task to run singular test case
    task automatic check_pe(
    /*
        Delay: 
        - +1 cycle for input to be registered
        - +1 cycle for output to be produced.
            Total: 2 cycles from input to output.
    */
      input logic signed [7:0] ai,
      input logic signed [7:0] bi, 
      input logic signed [31:0] ci,
      input logic valid_i,

      input logic signed [7:0] exp_ao,
      input logic signed [7:0] exp_bo,
      input logic signed [31:0] exp_co,
      
      input logic exp_valid_o
    );
    begin
        @(negedge clk);
        a_in = ai;
        b_in = bi;
        c_in = ci;
        valid_in = valid_i;

        @(posedge clk); // Wait for input to be registered - Repeat 2 cycles to ensure output is produced.
        @(posedge clk); // Wait for output to be produced

        // Check outputs
        total_tests++;
        if (a_out === exp_ao && b_out === exp_bo && c_out === exp_co && valid_out === exp_valid_o) begin
            $display("PASSED!: a_in=%0d, b_in=%0d, c_in=%0d => a_out=%0d, b_out=%0d, c_out=%0d", ai, bi, ci, a_out, b_out, c_out);
            passed++;
        end else begin
            $display("FAILED [Test %0d]: a_in=%0d, b_in=%0d, c_in=%0d => a_out=%0d, b_out=%0d, c_out=%0d (Expected: a_out=%0d, b_out=%0d, c_out=%0d)",
                    total_tests, ai, bi, ci, a_out, b_out, c_out, exp_ao, exp_bo, exp_co
            );
            failed++;
        end
    end
    endtask

    initial begin

        rst_n = 1'b0; // Assert reset
        
        repeat (3) @(negedge clk);

        rst_n = 1'b1; // Deassert reset
        @(posedge clk);
        #1

        $display("  Starting PE Testbench...");
        $display("****************************");

        check_pe(8'sd3, 8'sd5, 32'sd10, 1'b1, 8'sd3, 8'sd5, 32'sd25, 1);
        check_pe(8'sd127, 8'sd127, 32'sd0, 1'b1, 8'sd127, 8'sd127, 32'sd16129, 1);
        check_pe(-8'sd128, 8'sd127, 32'sd0, 1'b1, -8'sd128, 8'sd127, -32'sd16256, 1);
        check_pe(-8'sd128, -8'sd128, 32'sd0, 1'b1, -8'sd128, -8'sd128, 32'sd16384, 1);
        check_pe(8'sd0, 8'sd99, 32'sd0, 1'b1, 8'sd0, 8'sd99, 32'sd0, 1);
        check_pe(8'sd50, 8'sd60, 32'sd1000, 1'b1, 8'sd50, 8'sd60, 32'sd4000, 1);
        check_pe(8'sd1, 8'sd1, 32'sd2147483646, 1'b1, 8'sd1, 8'sd1, 32'sd2147483647, 1);

        $display("***************************");
        $display("----- Randomize Tests -----");
        $display("***************************");
        valid_in = 1'b0; // De-assert valid input for random tests
        for (int i = 0; i < 1000; i++) begin
            logic signed [7:0] ai = $urandom_range(0, 255);
            logic signed [7:0] bi = $urandom_range(0, 255);
            logic signed [31:0] ci = $urandom_range(0 , 1073741823);

            logic signed [7:0] exp_ao = ai;
            logic signed [7:0] exp_bo = bi;
            logic signed [31:0] exp_co = ci + ai * bi;

            check_pe(ai, bi, ci, 1'b1, exp_ao, exp_bo, exp_co, 1);
        end

        // Mid operation reset test
        $display("***************************************");
        $display(" ----- Mid-Operation Reset Tests ----- ");
        $display("***************************************");
        @(negedge clk);
        a_in = 8'sd10;
        b_in = 8'sd20;
        c_in = 32'sd100;
        valid_in = 1'b1; // Assert valid input

        @(posedge clk);

        @(negedge clk);
        rst_n = 1'b0; // Assert reset in the middle of operation

        @(posedge clk);
        check_pe(-8'sd719, 8'sd904, 32'sd1045, 1'b1, 8'sd0, 8'sd0, 32'sd0, 1'b0); // Expect outputs to be reset

        @(negedge clk);
        rst_n = 1'b1; // Deassert reset

        $display("****************************");
        $display(" ----- Valid-In False ----- ");
        $display("****************************");
        // @(negedge clk);
        // a_in = 8'sd10;
        // b_in = 8'sd20;
        // c_in = 32'sd100;
        // valid_in = 1'b1; // Assert valid input

        check_pe(8'sd10, 8'sd20, 32'sd100, 1'b1, 8'sd10, 8'sd20, 32'sd100, 1'b1); // Expect correct output before testing valid_in low

        // repeat(2) @(posedge clk);
        // a_in = 8'sd17;
        // b_in = 8'sd82;
        // c_in = 32'sd980;
        // valid_in = 1'b0; // De-assert valid input

        // repeat(2) @(posedge clk);
        check_pe(8'sd17, 8'sd82, 32'sd980, 1'b0, 8'sd10, 8'sd20, 32'sd100, 1'b0); // Expect no change when valid_in is low

        @(negedge clk);


        $finish;
    end

    
endmodule