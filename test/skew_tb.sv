`timescale 1ns/1ps

module skew_tb;

    localparam int ROWS = 14;
    localparam int COLS = 5;
    localparam int K = 7;
    localparam time PERIOD = 10ns;

    localparam int CYC_A = ROWS + K - 1;
    localparam int CYC_B = COLS + K - 1;
    localparam int CYC_TOT = (CYC_A > CYC_B) ? CYC_A : CYC_B; 
    logic clk;
    logic rst_n;
    logic start;

    logic signed [7:0] A_MAT [ROWS][K];
    logic signed [7:0] B_MAT [K][COLS];
	
    logic signed [7:0] SKEWED_A[ROWS];
    logic signed [7:0] SKEWED_B[COLS];
    logic 			  valid_a[ROWS];
    logic 			  valid_b[COLS];
    logic done;

    skew #(
        .ROWS(ROWS),
        .COLS(COLS),
        .K(K)
    ) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .A_MAT(A_MAT),
        .B_MAT(B_MAT),
        .SKEWED_A(SKEWED_A),
        .SKEWED_B(SKEWED_B),
        .valid_a(valid_a),
        .valid_b(valid_b),
        .done(done)
    );

    // Clock
    initial clk = 0;
    always #(PERIOD/2) clk <= ~clk;

    // Init Expected values
    // exp_A[cycle][row] -> expected `SKEWED_A[row]` at that `cycle`
    logic signed [7:0] exp_A [CYC_TOT][ROWS];
    logic signed [7:0] exp_B [CYC_TOT][COLS];
    logic              exp_validA [CYC_TOT][ROWS];
    logic              exp_validB [CYC_TOT][COLS];

    int error_count = 0;
    int total_tests = 0;

    // Task to check outputs against expected values on specified cycle
    task check_cycle(input int cycle);
        // Assert SKEWED_A and valid_a
        for (int r = 0; r < ROWS; r++) begin
            assert (SKEWED_A[r] === exp_A[cycle][r])
                else begin $error("Cycle %0d, SKEWED_A[%0d]: expected %0d, got %0d",
                            cycle, r, exp_A[cycle][r], SKEWED_A[r]); error_count++;
                end
            total_tests++;
            assert (valid_a[r] === exp_validA[cycle][r])
                else begin $error("Cycle %0d, valid_a[%0d]: expected %0b, got %0b",
                            cycle, r, exp_validA[cycle][r], valid_a[r]); error_count++;
                end
            total_tests++;
        end

        // Assert SKEWED_B and valid_b
        for (int c = 0; c < COLS; c++) begin
            assert (SKEWED_B[c] === exp_B[cycle][c])
                else begin $error("Cycle %0d, SKEWED_B[%0d]: expected %0d, got %0d",
                            cycle, c, exp_B[cycle][c], SKEWED_B[c]); error_count++;
                end
            total_tests++;
            assert (valid_b[c] === exp_validB[cycle][c])
                else begin $error("Cycle %0d, valid_b[%0d]: expected %0b, got %0b",
                            cycle, c, exp_validB[cycle][c], valid_b[c]); error_count++;
                end
            total_tests++;
        end

    endtask

    task set_expA(input signed [7:0] A [ROWS][K]);
        // Initialize the table to zero
        foreach (exp_A[i, j]) begin
            exp_A[i][j] = '0;
        end
        exp_validA = '{default: '0};

        // For each cycle and row, emit A[row][cycle-row] when index is in range.
        for (int cycle = 0; cycle < CYC_TOT; cycle++) begin
            for (int r = 0; r < ROWS; r++) begin
                int k_idx;
                k_idx = cycle - r;
                if ((k_idx >= 0) && (k_idx < K)) begin
                    exp_A[cycle][r] = A[r][k_idx];
                    exp_validA[cycle][r] = 1'b1;
                end
            end
        end
    endtask

    task set_expB(input signed [7:0] B [K][COLS]);
        // Initialize the table to zero
        foreach (exp_B[i, j]) begin
            exp_B[i][j] = '0;
        end
        exp_validB = '{default: '0};

        // For each cycle and column, emit B[cycle-col][col] when index is in range.
        for (int cycle = 0; cycle < CYC_TOT; cycle++) begin
            for (int c = 0; c < COLS; c++) begin
                int k_idx;
                k_idx = cycle - c;
                if ((k_idx >= 0) && (k_idx < K)) begin
                    exp_B[cycle][c] = B[k_idx][c];
                    exp_validB[cycle][c] = 1'b1;
                end
            end
        end
    endtask


    initial begin
        // Init signal
        rst_n = 0;
        start = 0;
        // Let state reset
        repeat (3) @(posedge clk);
        // Unlock state
        rst_n = 1;
        @(posedge clk);

        // Test 1: fill A and B with recognizable pattern
        for (int i = 0; i < ROWS; i++)
            for (int k = 0; k < K; k++)
                A_MAT[i][k] = i*10 + k;
        for (int k = 0; k < K; k++)
            for (int j = 0; j < COLS; j++)
                B_MAT[k][j] = k*10 + j;

        // Populate expected tables
        set_expA(A_MAT);
        set_expB(B_MAT);

        repeat (2) @(posedge clk);

        // Pulse start
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Run cycle check (including done pulse check per cycle)
        for (int cycle = 0; cycle < CYC_TOT; cycle++) begin
            @(posedge clk);
            check_cycle(cycle);

            if (cycle == CYC_TOT - 1) begin
                assert (done === 1'b1)
                    else begin $error("done not asserted on FINAL CYCLE. done: expected %0b, got %0b",
                                1'b1, done); error_count++;
                    end
                total_tests++;
            end
            else begin
                assert (done === 1'b0)
                    else begin $error("Done asserted at WRONG cycle. cycle: %0d, done: expected %0b, got %0b",
                                cycle, 1'b0, done); error_count++;
                    end
                    total_tests++;
            end
        end

        $display("Test 1 Completed. PASSED TESTS: %0d/%0d",
            (total_tests - error_count), total_tests);
        $finish;
    end

endmodule
