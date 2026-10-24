`timescale 1ns/1ps

module systolic_array_os_2x2_tb;

reg clk;
    reg rst_n;
    reg clear_acc;

reg signed [15:0] a_row0, a_row1;
    reg signed [15:0] b_col0, b_col1;

reg a_valid0, a_valid1;
    reg b_valid0, b_valid1;

    wire signed [31:0] c00, c01, c10, c11;

    integer errors;

systolic_array_os_2x2 dut (
        .clk(clk),
        .rst_n(rst_n),
        .clear_acc(clear_acc),

.a_row0(a_row0),
        .a_row1(a_row1),
        .b_col0(b_col0),
        .b_col1(b_col1),

.a_valid0(a_valid0),
        .a_valid1(a_valid1),
        .b_valid0(b_valid0),
        .b_valid1(b_valid1),

.c00(c00),
        .c01(c01),
        .c10(c10),
        .c11(c11)
    );

    always #5 clk = ~clk;

// Apply one scheduled clock cycle and check
    // all four accumulator values.
    task step;
        input integer test_no;

input signed [15:0] a0, a1;
        input signed [15:0] b0, b1;

        input av0, av1, bv0, bv1;

        input signed [31:0] e00, e01, e10, e11;

begin
            @(negedge clk);

a_row0 = a0;
            a_row1 = a1;
            b_col0 = b0;
            b_col1 = b1;

a_valid0 = av0;
            a_valid1 = av1;
            b_valid0 = bv0;
            b_valid1 = bv1;

@(posedge clk);
            #1;

if (c00 !== e00 ||
                c01 !== e01 ||
                c10 !== e10 ||
                c11 !== e11) begin

$display("FAIL TEST %0d", test_no);
                $display("Got: [%0d %0d; %0d %0d]",
                         c00, c01, c10, c11);
                $display("Expected: [%0d %0d; %0d %0d]",
                         e00, e01, e10, e11);

errors = errors + 1;
            end
            else begin
                $display(
                    "PASS TEST %0d: C = [%0d %0d; %0d %0d]",
                    test_no, c00, c01, c10, c11
                );
            end
        end
    endtask

initial begin
        clk = 0;
        rst_n = 0;
        clear_acc = 0;

a_row0 = 0;
        a_row1 = 0;
        b_col0 = 0;
        b_col1 = 0;

a_valid0 = 0;
        a_valid1 = 0;
        b_valid0 = 0;
        b_valid1 = 0;

        errors = 0;

repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1;

// ======================================
        // MATRIX TEST 1
        //
        // A = [1 2; 3 4]
        // B = [5 6; 7 8]
        //
        // Expected C = [19 22; 43 50]
        // ======================================

// E0
        step(1, 1,0, 5,0,
             1,0, 1,0,
             5,0,0,0);

// E1
        step(2, 2,3, 7,6,
             1,1, 1,1,
             19,6,15,0);

// E2
        step(3, 0,4, 0,8,
             0,1, 0,1,
             19,22,43,18);

// E3: final forwarded contribution
        step(4, 0,0, 0,0,
             0,0, 0,0,
             19,22,43,50);

// Invalid operands must not update sums.
        step(5, 100,100, 100,100,
             0,0, 0,0,
             19,22,43,50);

// ======================================
        // TEST 6: Clear all four accumulators
        // ======================================

        @(negedge clk);

clear_acc = 1;
        a_valid0 = 0;
        a_valid1 = 0;
        b_valid0 = 0;
        b_valid1 = 0;

@(posedge clk);
        #1;

if (c00 !== 0 || c01 !== 0 ||
            c10 !== 0 || c11 !== 0) begin
            $display("FAIL TEST 6: accumulator clear");
            errors = errors + 1;
        end
        else begin
            $display("PASS TEST 6: all accumulators cleared");
        end

@(negedge clk);
        clear_acc = 0;

// ======================================
        // MATRIX TEST 2
        //
        // A = [-2  5; 6 -1]
        // B = [-1  2; 3 -4]
        //
        // Expected C = [17 -24; -9 16]
        // ======================================

// E0
        step(7, -2,0, -1,0,
             1,0, 1,0,
             2,0,0,0);

// E1
        step(8, 5,6, 3,2,
             1,1, 1,1,
             17,-4,-6,0);

// E2
        step(9, 0,-1, 0,-4,
             0,1, 0,1,
             17,-24,-9,12);

// E3
        step(10, 0,0, 0,0,
             0,0, 0,0,
             17,-24,-9,16);

// Idle check
        step(11, 0,0, 0,0,
             0,0, 0,0,
             17,-24,-9,16);

// ======================================
        // FINAL SUMMARY
        // ======================================

if (errors == 0)
            $display("ALL 2x2 OS ARRAY TESTS PASSED");
        else
            $display("OS ARRAY FAILURES = %0d", errors);

$finish;
    end

endmodule
