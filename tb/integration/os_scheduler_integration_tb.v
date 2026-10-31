`timescale 1ns/1ps

module os_scheduler_integration_tb;
    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;
    reg start = 0;

    // Four 16-bit values per matrix, packed in row-major order.
    reg [63:0] a_matrix_flat = 0;
    reg [63:0] b_matrix_flat = 0;

    wire [31:0] a_left_flat;
    wire [31:0] b_top_flat;
    wire [1:0] a_valid_left;
    wire [1:0] b_valid_top;
    wire clear_acc, busy, done;
    wire [127:0] c_flat;

    integer errors = 0;
    integer t, r, c, k;
    integer idx;
    reg [31:0] expected_a, expected_b;
    reg [1:0] expected_av, expected_bv;
    reg signed [31:0] expected_sum, observed_sum;
    reg signed [15:0] A [0:1][0:1];
    reg signed [15:0] B [0:1][0:1];

    os_input_scheduler #(.DATA_WIDTH(16), .ROWS(2), .COLS(2), .K(2))
    scheduler (
        .clk(clk), .rst_n(rst_n), .start(start),
        .a_matrix_flat(a_matrix_flat), .b_matrix_flat(b_matrix_flat),
        .a_left_flat(a_left_flat), .b_top_flat(b_top_flat),
        .a_valid_left(a_valid_left), .b_valid_top(b_valid_top),
        .clear_acc(clear_acc), .busy(busy), .done(done)
    );

    os_array_param #(.DATA_WIDTH(16), .ACC_WIDTH(32), .ROWS(2), .COLS(2))
    array_dut (
        .clk(clk), .rst_n(rst_n), .clear_acc(clear_acc),
        .a_left_flat(a_left_flat), .a_valid_left(a_valid_left),
        .b_top_flat(b_top_flat), .b_valid_top(b_valid_top),
        .c_flat(c_flat)
    );

    task run_case;
        input integer case_id;
        begin
            if (case_id == 0) begin
                A[0][0]=1; A[0][1]=2;
                A[1][0]=3; A[1][1]=4;
                B[0][0]=5; B[0][1]=6;
                B[1][0]=7; B[1][1]=8;
            end else begin
                A[0][0]=-2; A[0][1]=5;
                A[1][0]=6;  A[1][1]=-1;
                B[0][0]=-1; B[0][1]=2;
                B[1][0]=3;  B[1][1]=-4;
            end

            // The scheduler expects a full matrix already buffered.
            @(negedge clk);
            a_matrix_flat = {A[1][1],A[1][0],A[0][1],A[0][0]};
            b_matrix_flat = {B[1][1],B[1][0],B[0][1],B[0][0]};
            start = 1;

            // Accept start; enter S_CLEAR.
            @(posedge clk); #1;
            start = 0;
            if (clear_acc !== 1'b1 || busy !== 1'b1 || done !== 1'b0) begin
                $display("FAIL case=%0d: expected CLEAR state", case_id);
                errors = errors + 1;
            end

            // Clear accumulators at the next rising edge; enter S_RUN.
            @(posedge clk); #1;
            if (clear_acc !== 1'b0 || busy !== 1'b1) begin
                $display("FAIL case=%0d: expected RUN state", case_id);
                errors = errors + 1;
            end

            for (t = 0; t < 4; t = t + 1) begin
                // Check the scheduler data/valid BEFORE the PE's edge.
                expected_a = 0;
                expected_b = 0;
                expected_av = 0;
                expected_bv = 0;

                for (r = 0; r < 2; r = r + 1) begin
                    idx = t-r;
                    if ((idx >= 0) && (idx < 2)) begin
                        expected_a[r*16 +:16] = A[r][idx];
                        expected_av[r] = 1'b1;
                    end
                end
                for (c = 0; c < 2; c = c + 1) begin
                    idx = t-c;
                    if ((idx >= 0) && (idx < 2)) begin
                        expected_b[c*16 +:16] = B[idx][c];
                        expected_bv[c] = 1'b1;
                    end
                end

                if (a_left_flat !== expected_a ||
                    b_top_flat !== expected_b ||
                    a_valid_left !== expected_av ||
                    b_valid_top !== expected_bv) begin
                    $display("FAIL case=%0d E%0d: scheduler stream", case_id, t);
                    errors = errors + 1;
                end

                // Processing edge E(t): PE registers capture operands.
                @(posedge clk); #1;
                for (r = 0; r < 2; r = r + 1) begin
                    for (c = 0; c < 2; c = c + 1) begin
                        expected_sum = 0;
                        for (k = 0; k < 2; k = k + 1) begin
                            if (r+c+k <= t)
                                expected_sum = expected_sum + A[r][k]*B[k][c];
                        end
                        observed_sum = $signed(c_flat[(r*2+c)*32 +: 32]);
                        if (observed_sum !== expected_sum) begin
                            $display("FAIL case=%0d E%0d PE(%0d,%0d): expected=%0d got=%0d",
                                     case_id, t, r, c, expected_sum, observed_sum);
                            errors = errors + 1;
                        end
                    end
                end
                $display("case=%0d E%0d C=[%0d %0d; %0d %0d]",
                         case_id, t,
                         $signed(c_flat[0 +:32]), $signed(c_flat[32 +:32]),
                         $signed(c_flat[64 +:32]), $signed(c_flat[96 +:32]));
            end

            if (done !== 1'b1 || busy !== 1'b0) begin
                $display("FAIL case=%0d: done not asserted after E3", case_id);
                errors = errors + 1;
            end
            @(posedge clk); #1; // S_DONE -> S_IDLE
            if (done !== 1'b0 || busy !== 1'b0) begin
                $display("FAIL case=%0d: done pulse did not end", case_id);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1;

        run_case(0);
        run_case(1);

        if (errors == 0)
            $display("ALL OS SCHEDULER INTEGRATION TESTS PASSED");
        else
            $fatal(1, "OS scheduler failures: %0d", errors);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Simulation timed out");
    end
endmodule
