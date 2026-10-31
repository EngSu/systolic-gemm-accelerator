`timescale 1ns/1ps

// Stage 10: parameterized scheduler + OS array integration test.
// Verifies three successive GEMMs: positive, signed and 16-bit high-magnitude.
// The testbench is designed for DATA_WIDTH=16, ACC_WIDTH=32.
module os_scheduler_param_tb #(
    parameter integer ROWS = 2,
    parameter integer K = 2,
    parameter integer COLS = 2,
    parameter integer DATA_WIDTH = 16,
    parameter integer ACC_WIDTH = 32
);
    localparam integer RUN_EDGES = K + ROWS + COLS - 2;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst_n = 1'b0;
    reg start = 1'b0;
    reg [ROWS*K*DATA_WIDTH-1:0] a_matrix_flat = 0;
    reg [K*COLS*DATA_WIDTH-1:0] b_matrix_flat = 0;

    wire [ROWS*DATA_WIDTH-1:0] a_left_flat;
    wire [COLS*DATA_WIDTH-1:0] b_top_flat;
    wire [ROWS-1:0] a_valid_left;
    wire [COLS-1:0] b_valid_top;
    wire clear_acc, busy, done;
    wire [ROWS*COLS*ACC_WIDTH-1:0] c_flat;

    reg signed [DATA_WIDTH-1:0] A [0:ROWS-1][0:K-1];
    reg signed [DATA_WIDTH-1:0] B [0:K-1][0:COLS-1];

    reg [ROWS*DATA_WIDTH-1:0] expected_a;
    reg [COLS*DATA_WIDTH-1:0] expected_b;
    reg [ROWS-1:0] expected_av;
    reg [COLS-1:0] expected_bv;
    reg signed [2*DATA_WIDTH-1:0] product;
    reg signed [ACC_WIDTH-1:0] expected_sum, observed_sum;

    integer errors = 0;
    integer cases_passed = 0;
    integer r, c, q, t, idx;

    os_input_scheduler #(
        .DATA_WIDTH(DATA_WIDTH), .ROWS(ROWS), .COLS(COLS), .K(K)
    ) scheduler (
        .clk(clk), .rst_n(rst_n), .start(start),
        .a_matrix_flat(a_matrix_flat), .b_matrix_flat(b_matrix_flat),
        .a_left_flat(a_left_flat), .b_top_flat(b_top_flat),
        .a_valid_left(a_valid_left), .b_valid_top(b_valid_top),
        .clear_acc(clear_acc), .busy(busy), .done(done)
    );

    os_array_param #(
        .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH),
        .ROWS(ROWS), .COLS(COLS)
    ) array_dut (
        .clk(clk), .rst_n(rst_n), .clear_acc(clear_acc),
        .a_left_flat(a_left_flat), .a_valid_left(a_valid_left),
        .b_top_flat(b_top_flat), .b_valid_top(b_valid_top),
        .c_flat(c_flat)
    );

    task run_case;
        input integer case_number;
        integer before_errors;
        begin
            before_errors = errors;
            // Match the existing Python baseline's two matrix patterns.
            // Case 2 additionally tests accumulation exceeding signed 32-bit range.
            for (r = 0; r < ROWS; r = r + 1) begin
                for (q = 0; q < K; q = q + 1) begin
                    if (case_number == 0)
                        A[r][q] = r*K + q + 1;
                    else if (case_number == 1)
                        A[r][q] = ((r+q)%2 == 0) ? -(r*K+q+1) : (r*K+q+1);
                    else
                        A[r][q] = 16'sd32767;
                end
            end
            for (q = 0; q < K; q = q + 1) begin
                for (c = 0; c < COLS; c = c + 1) begin
                    if (case_number == 0)
                        B[q][c] = 5 + q*COLS + c;
                    else if (case_number == 1)
                        B[q][c] = ((q+c)%2 == 0) ? (q*COLS+c+2) : -(q*COLS+c+2);
                    else
                        B[q][c] = 16'sd32767;
                end
            end

            @(negedge clk);
            a_matrix_flat = 0;
            b_matrix_flat = 0;
            // Row-major packing with A[0][0], B[0][0] at the LSB.
            for (r = 0; r < ROWS; r = r + 1)
                for (q = 0; q < K; q = q + 1)
                    a_matrix_flat[(r*K+q)*DATA_WIDTH +: DATA_WIDTH] = A[r][q];
            for (q = 0; q < K; q = q + 1)
                for (c = 0; c < COLS; c = c + 1)
                    b_matrix_flat[(q*COLS+c)*DATA_WIDTH +: DATA_WIDTH] = B[q][c];
            start = 1'b1;

            @(posedge clk); #1;
            start = 1'b0;
            if (clear_acc !== 1'b1 || busy !== 1'b1 || done !== 1'b0) begin
                $display("FAIL case=%0d: incorrect CLEAR entry", case_number);
                errors = errors + 1;
            end
            @(posedge clk); #1;
            if (clear_acc !== 1'b0 || busy !== 1'b1 || done !== 1'b0) begin
                $display("FAIL case=%0d: incorrect RUN entry", case_number);
                errors = errors + 1;
            end

            for (t = 0; t < RUN_EDGES; t = t + 1) begin
                expected_a = 0;
                expected_b = 0;
                expected_av = 0;
                expected_bv = 0;
                for (r = 0; r < ROWS; r = r + 1) begin
                    idx = t - r;
                    if (idx >= 0 && idx < K) begin
                        expected_a[r*DATA_WIDTH +: DATA_WIDTH] = A[r][idx];
                        expected_av[r] = 1'b1;
                    end
                end
                for (c = 0; c < COLS; c = c + 1) begin
                    idx = t - c;
                    if (idx >= 0 && idx < K) begin
                        expected_b[c*DATA_WIDTH +: DATA_WIDTH] = B[idx][c];
                        expected_bv[c] = 1'b1;
                    end
                end

                if (a_left_flat !== expected_a || b_top_flat !== expected_b ||
                    a_valid_left !== expected_av || b_valid_top !== expected_bv) begin
                    $display("FAIL case=%0d edge=%0d: scheduler operand/valid mismatch", case_number, t);
                    errors = errors + 1;
                end

                @(posedge clk); #1;
                for (r = 0; r < ROWS; r = r + 1) begin
                    for (c = 0; c < COLS; c = c + 1) begin
                        expected_sum = 0;
                        for (q = 0; q < K; q = q + 1) begin
                            if (r+c+q <= t) begin
                                product = A[r][q] * B[q][c];
                                expected_sum = expected_sum + $signed(product);
                            end
                        end
                        observed_sum = $signed(c_flat[(r*COLS+c)*ACC_WIDTH +: ACC_WIDTH]);
                        if (observed_sum !== expected_sum) begin
                            $display("FAIL case=%0d edge=%0d PE(%0d,%0d): expected=%0d got=%0d",
                                     case_number, t, r, c, expected_sum, observed_sum);
                            errors = errors + 1;
                        end
                    end
                end
            end

            if (done !== 1'b1 || busy !== 1'b0) begin
                $display("FAIL case=%0d: done must assert after last processing edge", case_number);
                errors = errors + 1;
            end
            @(posedge clk); #1;
            if (done !== 1'b0 || busy !== 1'b0) begin
                $display("FAIL case=%0d: done must be one cycle", case_number);
                errors = errors + 1;
            end
            if (errors == before_errors) begin
                cases_passed = cases_passed + 1;
                $display("PASS M=%0d K=%0d N=%0d case=%0d", ROWS, K, COLS, case_number);
            end
        end
    endtask

    initial begin
        if (DATA_WIDTH != 16 || ACC_WIDTH != 32)
            $fatal(1, "This testbench currently requires DATA_WIDTH=16 ACC_WIDTH=32");
        if (ROWS < 1 || K < 1 || COLS < 1)
            $fatal(1, "Matrix dimensions must be positive");

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        run_case(0);
        run_case(1);
        run_case(2);

        if (errors != 0)
            $fatal(1, "FAILED M=%0d K=%0d N=%0d with %0d error(s)", ROWS, K, COLS, errors);

        $display("ALL INTEGRATED OS PARAMETER TESTS PASSED M=%0d K=%0d N=%0d cases=%0d", ROWS, K, COLS, cases_passed);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Simulation timeout");
    end
endmodule
