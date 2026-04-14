`timescale 1ns/1ps

module pe_tb;

    localparam PE_PRINT_PASSED = 1'b0;
    
    logic clk;
    logic rst_n;

    logic signed [7:0] a_in;
    logic signed [7:0] b_in;
    logic valid_in;
    logic clear;

    logic signed [7:0] a_out;
    logic signed [7:0] b_out;
    logic signed [31:0] acc;

    // 1. Clock generation - 100MHz clock
    initial
        clk = 0;

    always #5 clk <= ~clk; // Toggle every 5ns - 10ns period for 100MHz


    // 2. Instantiate the PE module
    pe DUT (
        .clk(clk),
        .rst_n(rst_n),
        .clear(clear),

        .a_in(a_in),
        .b_in(b_in),
        .valid_in(valid_in),

        .a_out(a_out),
        .b_out(b_out),
        .acc(acc)
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
      input logic signed [31:0] acc_initial,
      input logic clr,
      input logic is_valid,

      input logic signed [7:0] exp_ao,
      input logic signed [7:0] exp_bo,
      input logic signed [31:0] exp_acc,

      input logic print_passed = 1'b1
    );
    begin
        @(negedge clk) begin
        a_in = ai;
        b_in = bi;
        valid_in = is_valid;
        clear = clr;
        end

        force DUT.acc = acc_initial; // Force the initial accumulator value for testing
        #1
        release DUT.acc; // Release the forced value to allow normal operation
        
        @(posedge clk); // Wait for input to be registered - Repeat 2 cycles to ensure output is produced.
        
        @(posedge clk); // Wait for output to be produced


        // Check outputs
        total_tests++;
        if (a_out === exp_ao && b_out === exp_bo && acc === exp_acc) begin
            if (print_passed)
                $display("PASSED!: {valid_in=%b} a_in=%0d, b_in=%0d, acc_initial=%0d => a_out=%0d, b_out=%0d, acc=%0d",
                            is_valid, ai, bi, acc_initial, a_out, b_out, exp_acc
                );
            passed++;
        end else begin
            $display("FAILED [Test %0d]: {valid_int=%b} a_in=%0d, b_in=%0d, acc_initial=%0d => a_out=%0d, b_out=%0d, acc=%0d (Expected: a_out=%0d, b_out=%0d, acc=%0d)",
                    total_tests, is_valid, ai, bi, acc_initial, a_out, b_out, acc, exp_ao, exp_bo, exp_acc
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

        $display("\n  Starting PE Testbench...");
        $display("------------------------------");

        check_pe(8'sd3, 8'sd5, 32'sd10, 1'b0, 1'b1, 8'sd3, 8'sd5, 32'sd25, 1'b1);
        check_pe(8'sd127, 8'sd127, 32'sd0, 1'b0, 1'b1, 8'sd127, 8'sd127, 32'sd16129, 1'b1);
        check_pe(-8'sd128, 8'sd127, 32'sd0, 1'b0, 1'b1, -8'sd128, 8'sd127, -32'sd16256, 1'b1);
        check_pe(-8'sd128, -8'sd128, 32'sd0, 1'b0, 1'b1, -8'sd128, -8'sd128, 32'sd16384, 1'b1);
        check_pe(8'sd0, 8'sd99, 32'sd0, 1'b0, 1'b1, 8'sd0, 8'sd99, 32'sd0, 1'b1);
        check_pe(8'sd50, 8'sd60, 32'sd1000, 1'b0, 1'b1, 8'sd50, 8'sd60, 32'sd4000, 1'b1);
        check_pe(8'sd1, 8'sd1, 32'sd2147483646, 1'b0, 1'b1, 8'sd1, 8'sd1, 32'sd2147483647, 1'b1);

    
        // Stress test to ensure no overflow issues and correct handling of all input combinations
        // DO NOT UNCOMMENT UNLESS YOU WANT TO RUN A VERY LONG TEST (256*256 = 65536 iterations)
        $display("\n*********************");
        $display("----- MAC Tests -----");
        $display("*********************");
        valid_in = 1'b0; // De-assert valid input for random tests

        for (int i = -128; i < 128; i++) begin
            for (int j = -128; j < 128; j++) begin
                logic signed [31:0] acc_initial = $signed($urandom()); // Random initial accumulator value

                logic signed [7:0] exp_ao = i[7:0];
                logic signed [7:0] exp_bo = j[7:0];
                logic signed [31:0] exp_acc = (exp_ao * exp_bo) + acc_initial;
                check_pe(exp_ao, exp_bo, acc_initial, 1'b0, 1'b1, exp_ao, exp_bo, exp_acc, PE_PRINT_PASSED);
                if (total_tests % 8000 == 0)
                    $display("Progress: %0d tests completed", total_tests);

            end
        end
    
        // Mid operation reset test
        $display("\n***************************************");
        $display(" ----- Mid-Operation Reset Tests ----- ");
        $display("***************************************");
        @(negedge clk);
        a_in = 8'sd10;
        b_in = 8'sd20;
        valid_in = 1'b1; // Assert valid input

        @(posedge clk);

        @(negedge clk);
        rst_n = 1'b0; // Assert reset in the middle of operation

        @(posedge clk);
        check_pe(-8'sd219, 8'sd107, 32'sd0, 1'b0, 1'b1, 8'sd0, 8'sd0, 32'sd0, 1'b1); // Expect outputs to be reset

        @(negedge clk);
        rst_n = 1'b1; // Deassert reset

        $display("\n****************************");
        $display(" ----- Valid-In False ----- ");
        $display("****************************");

        check_pe(8'sd10, 8'sd20, 32'sd0, 1'b0, 1'b1, 8'sd10, 8'sd20, 32'sd200, 1'b1); // Expect correct output before testing valid_in low

        check_pe(8'sd17, 8'sd82, 32'sd200, 1'b0, 1'b0, 8'sd10, 8'sd20, 32'sd200, 1'b1); // Expect no change when valid_in is low

        $display("\n************************");
        $display(" ----- Clear True  ----- ");
        $display("*************************");
        
        @(negedge clk);
        rst_n = 1'b0;

        @(negedge clk);
        rst_n = 1'b1;

        check_pe(8'sd12, 8'sd11, 32'sd900, 1'b0, 1'b1, 8'sd12, 8'sd11, 32'sd1032, 1'b1);

        check_pe(8'sd17, 8'sd82, 32'sd200, 1'b1, 1'b1, 8'sd17, 8'sd82, 32'sd0, 1'b1); // Expect no change when valid_in is low

        @(negedge clk);

        $display("\n------------------------------");
        // $display("Test Summary: Passed: %0d, Failed: %0d, Total: %0d", passed, failed, total_tests);
        $display("Test Summary: %0d / %0d tests passed", passed, total_tests);
        $finish;
    end

    
endmodule
