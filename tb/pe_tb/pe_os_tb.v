
`timescale 1ns/1ps

module pe_os_tb;

    reg clk;
    reg rst_n;
    reg clear_acc;
    reg valid_in;

    reg signed [15:0] a_in;
    reg signed [15:0] b_in;

    wire signed [15:0] a_out;
    wire signed [15:0] b_out;
    wire valid_out;
    wire signed [31:0] acc_out;

    integer errors;

    // Device Under Test (DUT)
    pe_os dut (
        .clk(clk),
        .rst_n(rst_n),
        .clear_acc(clear_acc),
        .valid_in(valid_in),
        .a_in(a_in),
        .b_in(b_in),
        .a_out(a_out),
        .b_out(b_out),
        .valid_out(valid_out),
        .acc_out(acc_out)
    );

    // Clock: 10 ns period (100 MHz)
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        clear_acc = 0;
        valid_in = 0;
        a_in = 0;
        b_in = 0;
        errors = 0;

        // Hold reset for two rising edges.
        repeat (2) @(posedge clk);

        // Release reset away from rising edge.
        @(negedge clk);
        rst_n = 1;

        // ----------------------------------------
        // TEST 1: 0 + (2 * 3) = 6
        // ----------------------------------------
        valid_in = 1;
        a_in = 2;
        b_in = 3;

        @(posedge clk);
        #1;

        if (acc_out !== 32'sd6) begin
            $display("FAIL TEST 1: expected 6, got %0d",
                     acc_out);
            errors = errors + 1;
        end
        else begin
            $display("PASS TEST 1: acc_out = %0d",
                     acc_out);
        end

        // ----------------------------------------
        // TEST 2: 6 + (5 * 4) = 26
        // ----------------------------------------
        @(negedge clk);
        a_in = 5;
        b_in = 4;

        @(posedge clk);
        #1;

        if (acc_out !== 32'sd26) begin
            $display("FAIL TEST 2: expected 26, got %0d",
                     acc_out);
            errors = errors + 1;
        end
        else begin
            $display("PASS TEST 2: acc_out = %0d",
                     acc_out);
        end

        // ----------------------------------------
        // TEST 3: 26 + (-2 * 3) = 20
        // ----------------------------------------
        @(negedge clk);
        a_in = -2;
        b_in = 3;

        @(posedge clk);
        #1;

        if (acc_out !== 32'sd20) begin
            $display("FAIL TEST 3: expected 20, got %0d",
                     acc_out);
            errors = errors + 1;
        end
        else begin
            $display("PASS TEST 3: acc_out = %0d",
                     acc_out);
        end

        // ----------------------------------------
        // TEST 4: Invalid input must not accumulate
        // ----------------------------------------
        @(negedge clk);
        valid_in = 0;
        a_in = 10;
        b_in = 10;

        @(posedge clk);
        #1;

        // Accumulator must hold its previous value.
        if (acc_out !== 32'sd20) begin
            $display("FAIL TEST 4: expected 20, got %0d",
                     acc_out);
            errors = errors + 1;
        end
        else begin
            $display("PASS TEST 4: accumulator held at %0d",
                     acc_out);
        end

        // Forwarded validity must be zero.
        if (valid_out !== 1'b0) begin
            $display("FAIL TEST 4: valid_out should be 0");
            errors = errors + 1;
        end

        // ----------------------------------------
        // FINAL TEST SUMMARY
        // ----------------------------------------
        if (errors == 0) begin
            $display("ALL PE OS TESTS PASSED");
        end
        else begin
            $display("PE OS TEST FAILURES = %0d", errors);
        end

        $finish;
    end

endmodule
