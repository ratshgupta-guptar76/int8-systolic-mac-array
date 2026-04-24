`timescale 1ns/1ps

`define TRUE = 1'b1
`define FALSE = 1'b0

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
    always #(PERIOD/2) clk = ~clk;

    // Init Expected values
    // exp_A[cycle][row] -> expected `SKEWED_A[row]` at that `cycle`
    logic signed [7:0] exp_A [CYC_TOT][ROWS];
    logic signed [7:0] exp_B [CYC_TOT][COLS];
    logic              exp_validA [CYC_TOT][ROWS];
    logic              exp_validB [CYC_TOT][COLS];

    // Task to check outputs against expected values on specified cycle
    task check_cycle(input int cycle);
        // Assert SKEWED_A and valid_a
        for (int r = 0; r < ROWS; r++) begin
            assert (SKEWED_A[r] === exp_A[cycle][r])
                else $error("Cycle %0d, SKEWED_A[%0d]: expected %0d, got %0d",
                            cycle, r, exp_A[cycle][r], SKEWED_A[r]);
            assert (valid_a[r] === exp_validA[cycle][r])
                else $error("Cycle %0d, valid_a[%0d]: expected %0b, got %0b",
                            cycle, r, exp_validA[cycle][r], valid_a[r]);
        end

        // Assert SKEWED_B and valid_b
        for (int c = 0; c < COLS; c++) begin
            assert (SKEWED_B[c] === exp_B[cycle][c])
                else $error("Cycle %0d, SKEWED_B[%0d]: expected %0d, got %0d",
                            cycle, c, exp_B[cycle][c], SKEWED_B[c]);
            assert (valid_b[c] === exp_validB[cycle][c])
                else $error("Cycle %0d, valid_b[%0d]: expected %0b, got %0b",
                            cycle, c, exp_validB[cycle][c], valid_b[c]);
        end

    endtask

    task set_expA (input signed [7:0] A [ROWS][K]) 
        // Initialize the table to zero
        for (int i = 0; i < CYC_TOT; i++)
            for (int j = 0; j < ROWS; j++)
                exp_A[i][j] = 8'sd0;
        exp_validA = `{default: 0}
        // Populate expected tables
        exp_A[0][0]=A[0][0];
        exp_A[1][0]=A[0][1]; exp_A[1][1]=A[1][0];
        exp_A[2][0]=A[0][2]; exp_A[2][1]=A[1][1]; exp_A[2][2]=A[2][0];
        exp_A[3][0]=A[0][3]; exp_A[3][1]=A[1][2]; exp_A[3][2]=A[2][1]; exp_A[3][3]=A[3][0];
                             exp_A[4][1]=A[1][3]; exp_A[4][2]=A[2][2]; exp_A[4][3]=A[3][1];
                                                  exp_A[5][2]=A[2][3]; exp_A[5][3]=A[3][2];
                                                                       exp_A[6][3]=A[3][3];        
        exp_validA[0][0]=T;
        exp_validA[1][0]=T; exp_validA[1][1]=T;
        exp_validA[2][0]=T; exp_validA[2][1]=T; exp_validA[2][2]=T;
        exp_validA[3][0]=T; exp_validA[3][1]=T; exp_validA[3][2]=T; exp_validA[3][3]=T;
                            exp_validA[4][1]=T; exp_validA[4][2]=T; exp_validA[4][3]=T;
                                                exp_validA[5][2]=T; exp_validA[5][3]=T;
                                                                    exp_validA[6][3]=T;
    endtask

    task set_expB (input signed [7:0] B [K][COLS])
        // Initialize the table to zero
        for (int i = 0; i < CYC_TOT; i++)
            for (int j = 0; j < COLS; j++)
                exp_B[i][j] = 8'sd0;

        exp_B[0][0]=B[0][0];
        exp_B[1][0]=B[1][0]; exp_B[1][1]=B[0][1];
        exp_B[2][0]=B[2][0]; exp_B[2][1]=B[1][1]; exp_B[2][2]=B[0][2];
        exp_B[3][0]=B[3][0]; exp_B[3][1]=B[2][1]; exp_B[3][2]=B[1][2]; exp_B[3][3]=B[0][3];
                             exp_B[4][1]=B[3][1]; exp_B[4][2]=B[2][2]; exp_B[4][3]=B[1][3];
                                                  exp_B[5][2]=B[3][2]; exp_B[5][3]=B[2][3];
                                                                       exp_B[6][3]=B[3][3];

        exp_validB[0][0]= TRUE;  exp_validB[1][1]=FALSE;  exp_validB[1][1]=FALSE;  exp_validB[1][1]=FALSE;
        exp_validB[1][0]= TRUE;  exp_validB[1][1]= TRUE;  exp_validB[1][1]=FALSE;  exp_validB[1][1]=FALSE;
        exp_validB[2][0]= TRUE;  exp_validB[2][1]= TRUE;  exp_validB[2][2]= TRUE;  exp_validB[1][1]=FALSE;
        exp_validB[3][0]= TRUE;  exp_validB[3][1]= TRUE;  exp_validB[3][2]= TRUE;  exp_validB[3][3]= TRUE;
        exp_validB[1][1]=FALSE;  exp_validB[4][1]= TRUE;  exp_validB[4][2]= TRUE;  exp_validB[4][3]= TRUE;
        exp_validB[1][1]=FALSE;  exp_validB[1][1]=FALSE;  exp_validB[5][2]= TRUE;  exp_validB[5][3]= TRUE;
        exp_validB[1][1]=FALSE;  exp_validB[1][1]=FALSE;  exp_validB[1][1]=FALSE;  exp_validB[6][3]= TRUE;
    endtask

    initial begin
        // Init signals
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
        repeat (2) @(posedge clk)
        // Pulse start
        start = 1'b1;
        @(posedge clk)
        start = 1'b0;

        // Run cycle check
        for (int cycle = 0; cycle < CYC_TOT; cycle++) begin
            @(posedge clk);
            check_cycle(cycle);
        end

        // Check done pulse on last cycle
        for (int c = 0; c < CYC_TOT; c++) begin
            if (c == CYC_TOT - 1)
                assert (done === 1'b1)
                    else $error("done Not asserted on FINAL CYCLE");
            else
                assert (done === 1'b0)
                    else $error("Done asserted at WRONG cycle. cycle: %0d", cycle); 
        end

        $display("Test 1 Completed");
        $finish;
    end

endmodule
