`timescale 1ns/1ps

module skew_tb;

    localparam int ROWS = 4;
    localparam int COLS = 4;
    localparam int K = 4;
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
    
    function automatic logic signed [7:0] rand_int8();
        return 8'($urandom_range(0, 255) - 128);
    endfunction

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

        exp_validA = '{default: '{default: '0}};

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
        exp_validB = '{default: '{default: '0}};

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

        // ========================================
        //      TEST 1 : Recognizable Pattern
        // ========================================
        error_count = 0;
        total_tests = 0;
        for (int i = 0; i < ROWS; i++) for (int k = 0; k < K; k++)
            A_MAT[i][k] = 8'(i*10 + k);
        for (int k = 0; k < K; k++) for (int j = 0; j < COLS; j++)
            B_MAT[k][j] = 8'(k*10 + j);

        // Populate expected tables
        set_expA(A_MAT);
        set_expB(B_MAT);

        // Pulse start
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Run cycle check
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

        // =======================================
        //      TEST 2 : Real vs Padding Zero
        // =======================================
        error_count = 0;
        total_tests = 0;
        for (int i = 0; i < ROWS; i++) for (int k = 0; k < K; k++)
            A_MAT[i][k] = rand_int8();
        for (int k = 0; k < K; k++) for (int j = 0; j < COLS; j++)
            B_MAT[k][j] = rand_int8();
        A_MAT[2][1] = 8'sd0; A_MAT[0][0] = 8'sd0;
        B_MAT[0][1] = 8'sd0; B_MAT[3][1] = 8'sd0;
        // Populate the expected tables
        set_expA(A_MAT);
        set_expB(B_MAT);

        // Pulse Start
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Run cycle check
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

        $display("Test 2 Completed. PASSED TESTS: %0d/%0d",
            (total_tests - error_count), total_tests);

        // ====================================
        //      TEST 3 : Check Matrix Copy
        // ====================================
        error_count = 0;
        total_tests = 0;
        for (int i = 0; i < ROWS; i++) for (int k = 0; k < K; k++)
            A_MAT[i][k] = rand_int8();
        for (int k = 0; k < K; k++) for (int j = 0; j < COLS; j++)
            B_MAT[k][j] = rand_int8();

        // Populate the expected tables
        set_expA(A_MAT);
        set_expB(B_MAT);

        // Pulse Start
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Run cycle check
        for (int cycle = 0; cycle < CYC_TOT; cycle++) begin
            // Change A & B Matrices
                for (int i = 0; i < ROWS; i++) for (int k = 0; k < K; k++)
                    A_MAT[i][k] = rand_int8();
                for (int k = 0; k < K; k++) for (int j = 0; j < COLS; j++)
                    B_MAT[k][j] = rand_int8();

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

        set_expA(A_MAT);
        set_expB(B_MAT);

        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Run cycle check again
        for (int cycle = 0; cycle < CYC_TOT; cycle++) begin
            // Change A & B Matrices
            for (int i = 0; i < ROWS; i++) for (int k = 0; k < K; k++)
                    A_MAT[i][k] = rand_int8();
            for (int k = 0; k < K; k++) for (int j = 0; j < COLS; j++)
                    B_MAT[k][j] = rand_int8();

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

        $display("Test 3 Completed. PASSED TESTS: %0d/%0d",
            (total_tests - error_count), total_tests);

        // ==========================
        //      TEST 4 : reset_n
        // ==========================
        error_count = 0;
        total_tests = 0;
        for (int i = 0; i < ROWS; i++) for (int k = 0; k < K; k++)
            A_MAT[i][k] = rand_int8();
        for (int k = 0; k < K; k++) for (int j = 0; j < COLS; j++)
            B_MAT[k][j] = rand_int8();

        // Populate the expected tables
        set_expA(A_MAT);
        set_expB(B_MAT);

        // Pulse Start
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Run cycle check
        for (int cycle = 0; cycle < 2; cycle++) begin
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

        // @(posedge clk);
        rst_n = 1'b0;
        // foreach (exp_A[i, j])
        //     exp_A[i][j] = 8'sd0;
        // foreach (exp_B[i, j])
        //    exp_B[i][j] = 8'sd0;

        // exp_validA = '{default: '0};
        // exp_validB = '{default: '0};
        @(negedge clk);
        rst_n = 1'b1;

        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

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

        $display("Test 4 Completed. PASSED TESTS: %0d/%0d",
            (total_tests - error_count), total_tests);

        // ==================================
        //      TEST 5 : Signed Extremes
        // ==================================
        error_count = 0;
        total_tests = 0;
        for (int i = 0; i < ROWS; i++) for (int k = 0; k < K; k++)
            A_MAT[i][k] = rand_int8();
        for (int k = 0; k < K; k++) for (int j = 0; j < COLS; j++)
            B_MAT[k][j] = rand_int8();
        A_MAT[0][2] = 127; A_MAT[0][3] = -128; A_MAT[1][1] = 1; A_MAT[1][2] = -1;
        A_MAT[3][1] = 127; A_MAT[2][2] = -128; A_MAT[3][3] = 1; A_MAT[2][3] = -1;

        // Populate the expected tables
        set_expA(A_MAT);
        set_expB(B_MAT);

        // Pulse Start
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Run cycle check
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

        $display("Test 5 Completed. PASSED TESTS: %0d/%0d",
            (total_tests - error_count), total_tests);
        
        // ===================================
        //      TEST 6 : Back-to-Back Run
        // ===================================
        error_count = 0;
        total_tests = 0;
        for (int i = 0; i < ROWS; i++) for (int k = 0; k < K; k++)
            A_MAT[i][k] = rand_int8();
        for (int k = 0; k < K; k++) for (int j = 0; j < COLS; j++)
            B_MAT[k][j] = rand_int8();

        // Populate the expected tables
        set_expA(A_MAT);
        set_expB(B_MAT);

        // Pulse Start
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Run cycle check
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

        // Change A & B Matrices
        for (int i = 0; i < ROWS; i++) for (int k = 0; k < K; k++)
            A_MAT[i][k] = rand_int8();
        for (int k = 0; k < K; k++) for (int j = 0; j < COLS; j++)
            B_MAT[k][j] = rand_int8();

        set_expA(A_MAT);
        set_expB(B_MAT);

        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Run cycle check again
        for (int cycle = 0; cycle < CYC_TOT; cycle++) begin
            // Change A & B Matrices
                for (int i = 0; i < ROWS; i++) for (int k = 0; k < K; k++)
                    A_MAT[i][k] = rand_int8();
                for (int k = 0; k < K; k++) for (int j = 0; j < COLS; j++)
                    B_MAT[k][j] = rand_int8();

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

        $display("Test 6 Completed. PASSED TESTS: %0d/%0d",
            (total_tests - error_count), total_tests);


        $finish;
    end

endmodule
