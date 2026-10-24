
`timescale 1ns/1ps

module ws_array_param_tb;

    parameter M_ROWS   = 2;
    parameter K_STAGES = 2;
    parameter COLS     = 2;

    localparam DATA_WIDTH = 16;
    localparam ACC_WIDTH  = 32;
    localparam TOTAL_EDGES = M_ROWS + K_STAGES - 1;

    reg clk;
    reg rst_n;
    reg load_weights;

    reg [K_STAGES*COLS*DATA_WIDTH-1:0] weights_flat;
    reg [K_STAGES*DATA_WIDTH-1:0] activation_flat;
    reg [K_STAGES-1:0] activation_valid;

    wire [COLS*ACC_WIDTH-1:0] result_flat;
    wire [COLS-1:0] result_valid;

    reg signed [DATA_WIDTH-1:0]
        A [0:M_ROWS-1][0:K_STAGES-1];

    reg signed [DATA_WIDTH-1:0]
        B [0:K_STAGES-1][0:COLS-1];

    integer errors;

    // ----------------------------------------
    // Device Under Test
    // ----------------------------------------

    ws_array_param #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .K_STAGES(K_STAGES),
        .COLS(COLS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .load_weights(load_weights),
        .weights_flat(weights_flat),
        .activation_flat(activation_flat),
        .activation_valid(activation_valid),
        .result_flat(result_flat),
        .result_valid(result_valid)
    );

    // Clock period = 10 ns
    always #5 clk = ~clk;

    // ----------------------------------------
    // Run one GEMM test case
    // ----------------------------------------

    task run_case;
        input integer case_id;

        integer m, k, c, t;
        integer row_index;
        integer completed_row;

        reg expected_valid;
        reg signed [ACC_WIDTH-1:0] expected;
        reg signed [ACC_WIDTH-1:0] observed;

        begin

            // --------------------------------
            // Generate matrix A
            // --------------------------------

            for (m = 0; m < M_ROWS; m = m + 1) begin
                for (k = 0; k < K_STAGES; k = k + 1) begin

                    if (case_id == 0)
                        A[m][k] = m*K_STAGES + k + 1;

                    else if ((m+k) % 2 == 0)
                        A[m][k] = -(m*K_STAGES + k + 1);

                    else
                        A[m][k] = m*K_STAGES + k + 1;

                end
            end

            // --------------------------------
            // Generate matrix B
            // --------------------------------

            for (k = 0; k < K_STAGES; k = k + 1) begin
                for (c = 0; c < COLS; c = c + 1) begin

                    if (case_id == 0)
                        B[k][c] = 5 + k*COLS + c;

                    else if ((k+c) % 2 == 0)
                        B[k][c] = k*COLS + c + 2;

                    else
                        B[k][c] = -(k*COLS + c + 2);

                end
            end

            // --------------------------------
            // Load stationary weights
            // --------------------------------

            @(negedge clk);

            load_weights = 1'b1;
            weights_flat = 0;
            activation_flat = 0;
            activation_valid = 0;

            for (k = 0; k < K_STAGES; k = k + 1) begin
                for (c = 0; c < COLS; c = c + 1) begin

                    weights_flat[
                        (k*COLS+c)*DATA_WIDTH
                        +: DATA_WIDTH
                    ] = B[k][c];

                end
            end

            @(posedge clk);
            #1;

            if (result_valid !== {COLS{1'b0}}) begin

                $display(
                    "FAIL: valid output during weight loading"
                );

                errors = errors + 1;

            end
            else begin

                $display(
                    "PASS: weights loaded for case %0d",
                    case_id
                );

            end

            // Release weight loading
            @(negedge clk);

            load_weights = 1'b0;

            // --------------------------------
            // Stream activations
            // --------------------------------

            for (t = 0; t < TOTAL_EDGES; t = t + 1) begin

                activation_flat = 0;
                activation_valid = 0;

                // Stage k receives A[m][k]
                // at processing edge t = m + k.

                for (k = 0; k < K_STAGES; k = k + 1) begin

                    row_index = t - k;

                    if (row_index >= 0 &&
                        row_index < M_ROWS) begin

                        activation_flat[
                            k*DATA_WIDTH +: DATA_WIDTH
                        ] = A[row_index][k];

                        activation_valid[k] = 1'b1;

                    end
                end

                // Capture PE outputs
                @(posedge clk);
                #1;

                completed_row = t - (K_STAGES - 1);

                expected_valid =
                    (completed_row >= 0 &&
                     completed_row < M_ROWS);

                // --------------------------------
                // Check output validity and data
                // --------------------------------

                for (c = 0; c < COLS; c = c + 1) begin

                    if (result_valid[c] !== expected_valid) begin

                        $display(
                            "FAIL VALID: case=%0d edge=%0d col=%0d expected=%b got=%b",
                            case_id, t, c,
                            expected_valid, result_valid[c]
                        );

                        errors = errors + 1;

                    end

                    if (expected_valid) begin

                        expected = 0;

                        // Software-style dot product
                        for (k = 0; k < K_STAGES; k = k + 1) begin

                            expected = expected +
                                A[completed_row][k] * B[k][c];

                        end

                        observed = $signed(
                            result_flat[
                                c*ACC_WIDTH +: ACC_WIDTH
                            ]
                        );

                        if (observed !== expected) begin

                            $display(
                                "FAIL DATA: case=%0d row=%0d col=%0d",
                                case_id, completed_row, c
                            );

                            $display(
                                "Expected=%0d Got=%0d",
                                expected, observed
                            );

                            errors = errors + 1;

                        end

                    end

                end

                // --------------------------------
                // Print each completed output row
                // --------------------------------

                if (expected_valid) begin

                    $write(
                        "Case %0d row %0d: ",
                        case_id, completed_row
                    );

                    for (c = 0; c < COLS; c = c + 1) begin

                        observed = $signed(
                            result_flat[
                                c*ACC_WIDTH +: ACC_WIDTH
                            ]
                        );

                        $write("%0d ", observed);

                    end

                    $write("\n");

                end

                // Drive next cycle away from posedge
                if (t < TOTAL_EDGES-1)
                    @(negedge clk);

            end

            $display(
                "COMPLETED case=%0d M=%0d K=%0d N=%0d",
                case_id, M_ROWS, K_STAGES, COLS
            );

        end
    endtask

    // ----------------------------------------
    // Main simulation
    // ----------------------------------------

    initial begin

        clk = 0;
        rst_n = 0;
        load_weights = 0;

        weights_flat = 0;
        activation_flat = 0;
        activation_valid = 0;

        errors = 0;

        // Initial asynchronous reset
        repeat (2) @(posedge clk);

        @(negedge clk);
        rst_n = 1;

        // Test 0: Positive matrix values
        run_case(0);

        // Test 1: Mixed signed matrix values
        run_case(1);

        // --------------------------------
        // Final summary
        // --------------------------------

        if (errors == 0) begin

            $display(
                "ALL PARAMETERIZED WS ARRAY TESTS PASSED"
            );

        end
        else begin

            $fatal(
                1,
                "PARAMETERIZED WS ARRAY FAILURES: %0d",
                errors
            );

        end

        $finish;

    end

endmodule

