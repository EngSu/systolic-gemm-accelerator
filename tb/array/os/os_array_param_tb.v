
`timescale 1ns/1ps

module os_array_param_tb;

    parameter ROWS = 2;
    parameter COLS = 2;
    parameter K    = 2;

    localparam DATA_WIDTH = 16;
    localparam ACC_WIDTH  = 32;

    localparam TOTAL_EDGES = K + ROWS + COLS - 2;

    reg clk;
    reg rst_n;
    reg clear_acc;

    reg [ROWS*DATA_WIDTH-1:0] a_left_flat;
    reg [COLS*DATA_WIDTH-1:0] b_top_flat;

    reg [ROWS-1:0] a_valid_left;
    reg [COLS-1:0] b_valid_top;

    wire [ROWS*COLS*ACC_WIDTH-1:0] c_flat;

    reg signed [DATA_WIDTH-1:0] A [0:ROWS-1][0:K-1];
    reg signed [DATA_WIDTH-1:0] B [0:K-1][0:COLS-1];

    integer errors;

    // -----------------------------------------
    // Device Under Test
    // -----------------------------------------

    os_array_param #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .ROWS(ROWS),
        .COLS(COLS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .clear_acc(clear_acc),

        .a_left_flat(a_left_flat),
        .a_valid_left(a_valid_left),

        .b_top_flat(b_top_flat),
        .b_valid_top(b_valid_top),

        .c_flat(c_flat)
    );

    // Clock period = 10 ns
    always #5 clk = ~clk;

    // -----------------------------------------
    // Run a complete matrix-multiplication case
    // -----------------------------------------

    task run_case;
        input integer case_id;

        integer r, c, k, t;
        integer a_index, b_index;

        reg signed [ACC_WIDTH-1:0] expected;
        reg signed [ACC_WIDTH-1:0] observed;

        begin

            // Generate matrix A
            for (r = 0; r < ROWS; r = r + 1) begin
                for (k = 0; k < K; k = k + 1) begin

                    if (case_id == 0)
                        A[r][k] = r*K + k + 1;
                    else if ((r+k) % 2 == 0)
                        A[r][k] = -(r*K + k + 1);
                    else
                        A[r][k] = r*K + k + 1;

                end
            end

            // Generate matrix B
            for (k = 0; k < K; k = k + 1) begin
                for (c = 0; c < COLS; c = c + 1) begin

                    if (case_id == 0)
                        B[k][c] = 5 + k*COLS + c;
                    else if ((k+c) % 2 == 0)
                        B[k][c] = k*COLS + c + 2;
                    else
                        B[k][c] = -(k*COLS + c + 2);

                end
            end

            // ---------------------------------
            // Clear all accumulator registers
            // ---------------------------------

            @(negedge clk);

            clear_acc = 1'b1;

            a_left_flat = 0;
            b_top_flat = 0;

            a_valid_left = 0;
            b_valid_top = 0;

            @(posedge clk);
            #1;

            for (r = 0; r < ROWS; r = r + 1) begin
                for (c = 0; c < COLS; c = c + 1) begin

                    observed = $signed(
                        c_flat[
                            ((r*COLS+c)*ACC_WIDTH)
                            +: ACC_WIDTH
                        ]
                    );

                    if (observed !== 0) begin
                        $display(
                            "FAIL CLEAR: PE(%0d,%0d) = %0d",
                            r, c, observed
                        );

                        errors = errors + 1;
                    end
                end
            end

            // Begin new calculation
            @(negedge clk);
            clear_acc = 1'b0;

            // ---------------------------------
            // Apply skewed inputs
            // ---------------------------------

            for (t = 0; t < TOTAL_EDGES; t = t + 1) begin

                a_left_flat = 0;
                b_top_flat = 0;

                a_valid_left = 0;
                b_valid_top = 0;

                // A[row][k] enters at edge row+k
                for (r = 0; r < ROWS; r = r + 1) begin

                    a_index = t - r;

                    if (a_index >= 0 && a_index < K) begin

                        a_left_flat[
                            r*DATA_WIDTH +: DATA_WIDTH
                        ] = A[r][a_index];

                        a_valid_left[r] = 1'b1;
                    end
                end

                // B[k][column] enters at edge column+k
                for (c = 0; c < COLS; c = c + 1) begin

                    b_index = t - c;

                    if (b_index >= 0 && b_index < K) begin

                        b_top_flat[
                            c*DATA_WIDTH +: DATA_WIDTH
                        ] = B[b_index][c];

                        b_valid_top[c] = 1'b1;
                    end
                end

                // Wait for the next processing edge
                @(posedge clk);
                #1;

                // ---------------------------------
                // Check every PE's accumulator
                // ---------------------------------

                for (r = 0; r < ROWS; r = r + 1) begin
                    for (c = 0; c < COLS; c = c + 1) begin

                        expected = 0;

                        for (k = 0; k < K; k = k + 1) begin

                            // Term k reaches PE(r,c)
                            // at processing edge r+c+k.
                            if ((r+c+k) <= t) begin

                                expected = expected
                                         + A[r][k] * B[k][c];

                            end
                        end

                        observed = $signed(
                            c_flat[
                                ((r*COLS+c)*ACC_WIDTH)
                                +: ACC_WIDTH
                            ]
                        );

                        if (observed !== expected) begin

                            $display(
                                "FAIL case=%0d edge=%0d PE(%0d,%0d)",
                                case_id, t, r, c
                            );

                            $display(
                                "  Expected=%0d Got=%0d",
                                expected, observed
                            );

                            errors = errors + 1;
                        end
                    end
                end

                // Drive the next inputs away from posedge
                if (t < TOTAL_EDGES-1)
                    @(negedge clk);

            end

            $display(
                "COMPLETED case=%0d array=%0dx%0d K=%0d",
                case_id, ROWS, COLS, K
            );

            // Display the completed output matrix
            $display("Final C matrix:");

            for (r = 0; r < ROWS; r = r + 1) begin

                for (c = 0; c < COLS; c = c + 1) begin

                    observed = $signed(
                        c_flat[
                            ((r*COLS+c)*ACC_WIDTH)
                            +: ACC_WIDTH
                        ]
                    );

                    $write("%0d ", observed);
                end

                $write("\n");
            end

        end
    endtask

    // -----------------------------------------
    // Main simulation
    // -----------------------------------------

    initial begin

        clk = 0;
        rst_n = 0;
        clear_acc = 0;

        a_left_flat = 0;
        b_top_flat = 0;

        a_valid_left = 0;
        b_valid_top = 0;

        errors = 0;

        repeat (2) @(posedge clk);

        @(negedge clk);
        rst_n = 1;

        // Positive matrix operands
        run_case(0);

        // Mixed signed operands
        run_case(1);

        if (errors == 0) begin
            $display(
                "ALL PARAMETERIZED OS ARRAY TESTS PASSED"
            );
        end
        else begin
            $fatal(
                1,
                "PARAMETERIZED OS ARRAY FAILURES: %0d",
                errors
            );
        end

        $finish;

    end

endmodule

