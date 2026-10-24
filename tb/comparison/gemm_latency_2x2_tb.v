
`timescale 1ns/1ps

module gemm_latency_2x2_tb;

    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;
    reg clear_acc = 0;
    reg load_weights = 0;

    // Output-stationary inputs
    reg [31:0] a_left_flat = 0;
    reg [31:0] b_top_flat = 0;
    reg [1:0] a_valid_left = 0;
    reg [1:0] b_valid_top = 0;
    wire [127:0] os_c_flat;

    // Weight-stationary inputs
    reg [63:0] weights_flat = 0;
    reg [31:0] activation_flat = 0;
    reg [1:0] activation_valid = 0;

    wire [63:0] ws_result_flat;
    wire [1:0] ws_result_valid;

    integer t;
    integer first_ws = -1;
    integer last_ws = -1;
    integer os_complete = -1;

    // ----------------------------------------
    // OS architecture
    // ----------------------------------------

    os_array_param #(
        .DATA_WIDTH(16),
        .ACC_WIDTH(32),
        .ROWS(2),
        .COLS(2)
    ) os_dut (
        .clk(clk),
        .rst_n(rst_n),
        .clear_acc(clear_acc),
        .a_left_flat(a_left_flat),
        .a_valid_left(a_valid_left),
        .b_top_flat(b_top_flat),
        .b_valid_top(b_valid_top),
        .c_flat(os_c_flat)
    );

    // ----------------------------------------
    // WS architecture
    // ----------------------------------------

    ws_array_param #(
        .DATA_WIDTH(16),
        .ACC_WIDTH(32),
        .K_STAGES(2),
        .COLS(2)
    ) ws_dut (
        .clk(clk),
        .rst_n(rst_n),
        .load_weights(load_weights),
        .weights_flat(weights_flat),
        .activation_flat(activation_flat),
        .activation_valid(activation_valid),
        .result_flat(ws_result_flat),
        .result_valid(ws_result_valid)
    );

    // ----------------------------------------
    // Check all four OS accumulator values
    // ----------------------------------------

    task check_os;
        input integer edge_number;
        input signed [31:0] e00, e01, e10, e11;

        begin
            if ($signed(os_c_flat[0 +: 32]) !== e00 ||
                $signed(os_c_flat[32 +: 32]) !== e01 ||
                $signed(os_c_flat[64 +: 32]) !== e10 ||
                $signed(os_c_flat[96 +: 32]) !== e11) begin

                $display(
                    "OS actual: [%0d %0d; %0d %0d]",
                    $signed(os_c_flat[0 +: 32]),
                    $signed(os_c_flat[32 +: 32]),
                    $signed(os_c_flat[64 +: 32]),
                    $signed(os_c_flat[96 +: 32])
                );

                $fatal(
                    1, "OS mismatch at E%0d",
                    edge_number
                );
            end
        end
    endtask

    // ----------------------------------------
    // Check WS output validity and values
    // ----------------------------------------

    task check_ws;
        input integer edge_number;
        input [1:0] expected_valid;
        input signed [31:0] expected_col0;
        input signed [31:0] expected_col1;

        begin
            if (ws_result_valid !== expected_valid)
                $fatal(
                    1,
                    "WS valid mismatch at E%0d",
                    edge_number
                );

            if (expected_valid == 2'b11 &&
                ($signed(ws_result_flat[0 +: 32])
                    !== expected_col0 ||
                 $signed(ws_result_flat[32 +: 32])
                    !== expected_col1)) begin

                $fatal(
                    1,
                    "WS data mismatch at E%0d",
                    edge_number
                );
            end
        end
    endtask

    // ----------------------------------------
    // Main experiment
    // ----------------------------------------

    initial begin

        // Hold reset through two rising edges
        repeat (2) @(posedge clk);

        // ------------------------------------
        // Setup edge
        // ------------------------------------

        @(negedge clk);

        rst_n = 1;
        clear_acc = 1;
        load_weights = 1;

        // Packed B = [5 6; 7 8]
        weights_flat = {
            16'sd8, 16'sd7,
            16'sd6, 16'sd5
        };

        @(posedge clk);
        #1;

        check_os(-1, 0, 0, 0, 0);
        check_ws(-1, 2'b00, 0, 0);

        $display(
            "SETUP: OS cleared; WS weights loaded"
        );

        // ------------------------------------
        // Processing edges E0 to E3
        // ------------------------------------

        for (t = 0; t < 4; t = t + 1) begin

            @(negedge clk);

            clear_acc = 0;
            load_weights = 0;

            // Default: all inputs invalid
            a_left_flat = 0;
            b_top_flat = 0;
            a_valid_left = 0;
            b_valid_top = 0;

            activation_flat = 0;
            activation_valid = 0;

            case (t)

                // E0
                0: begin
                    a_left_flat = {16'sd0, 16'sd1};
                    b_top_flat = {16'sd0, 16'sd5};

                    a_valid_left = 2'b01;
                    b_valid_top = 2'b01;

                    activation_flat = {16'sd0, 16'sd1};
                    activation_valid = 2'b01;
                end

                // E1
                1: begin
                    a_left_flat = {16'sd3, 16'sd2};
                    b_top_flat = {16'sd6, 16'sd7};

                    a_valid_left = 2'b11;
                    b_valid_top = 2'b11;

                    activation_flat = {16'sd2, 16'sd3};
                    activation_valid = 2'b11;
                end

                // E2
                2: begin
                    a_left_flat = {16'sd4, 16'sd0};
                    b_top_flat = {16'sd8, 16'sd0};

                    a_valid_left = 2'b10;
                    b_valid_top = 2'b10;

                    activation_flat = {16'sd4, 16'sd0};
                    activation_valid = 2'b10;
                end

                // E3: flush
                default: begin
                end

            endcase

            @(posedge clk);
            #1;

            // Check expected partial and final results.
            case (t)
                0: begin
                    check_os(t, 5, 0, 0, 0);
                    check_ws(t, 2'b00, 0, 0);
                end

                1: begin
                    check_os(t, 19, 6, 15, 0);
                    check_ws(t, 2'b11, 19, 22);
                end

                2: begin
                    check_os(t, 19, 22, 43, 18);
                    check_ws(t, 2'b11, 43, 50);
                end

                3: begin
                    check_os(t, 19, 22, 43, 50);
                    check_ws(t, 2'b00, 0, 0);
                end
            endcase

            // Record WS output timing.
            if (ws_result_valid == 2'b11) begin

                if (first_ws == -1)
                    first_ws = t;

                last_ws = t;
            end

            // Detect when every OS output is complete.
            if (os_complete == -1 &&
                os_c_flat[0 +: 32] == 32'd19 &&
                os_c_flat[32 +: 32] == 32'd22 &&
                os_c_flat[64 +: 32] == 32'd43 &&
                os_c_flat[96 +: 32] == 32'd50) begin

                os_complete = t;
            end

            $display(
                "E%0d: WS_valid=%b OS_C=[%0d %0d; %0d %0d]",
                t,
                ws_result_valid,
                $signed(os_c_flat[0 +: 32]),
                $signed(os_c_flat[32 +: 32]),
                $signed(os_c_flat[64 +: 32]),
                $signed(os_c_flat[96 +: 32])
            );

        end

        // ------------------------------------
        // Verify observed cycle markers
        // ------------------------------------

        if (first_ws !== 1 ||
            last_ws !== 2 ||
            os_complete !== 3) begin

            $fatal(
                1,
                "Unexpected timing markers"
            );
        end

        $display("WS first output: E%0d", first_ws);
        $display("WS last output:  E%0d", last_ws);
        $display("OS full matrix:  E%0d", os_complete);

        $display(
            "PASS: 2x2 OS/WS cycle timing matches baseline"
        );

        $finish;

    end

endmodule

