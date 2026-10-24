`timescale 1ns/1ps


module ws_array_2x2_tb;

reg clk;
reg rst_n;
reg load_weights;

reg signed [15:0] b00, b01, b10, b11;
reg signed [15:0] a_k0_in, a_k1_in;
reg a_k0_valid, a_k1_valid;

wire signed [31:0] c_col0, c_col1;
wire c_col0_valid, c_col1_valid;

integer errors;

ws_array_2x2 dut (
.clk(clk),
.rst_n(rst_n),
.load_weights(load_weights),

.b00(b00),
.b01(b01),
.b10(b10),
.b11(b11),

.a_k0_in(a_k0_in),
.a_k1_in(a_k1_in),
.a_k0_valid(a_k0_valid),
.a_k1_valid(a_k1_valid),

.c_col0(c_col0),
.c_col1(c_col1),
.c_col0_valid(c_col0_valid),
.c_col1_valid(c_col1_valid)
);

// 10 ns clock
always #5 clk = ~clk;

// Check both columns after a rising edge.
task check_after_edge;
input integer test_number;
input signed [31:0] expected0;
input signed [31:0] expected1;
input expected_valid;

begin
@(posedge clk);
#1;

if (c_col0 !== expected0 ||
c_col1 !== expected1 ||
c_col0_valid !== expected_valid ||
c_col1_valid !== expected_valid) begin

$display("FAIL TEST %0d", test_number);
$display(
"  Got:      col0=%0d col1=%0d valid=%b,%b",
c_col0, c_col1,
c_col0_valid, c_col1_valid
);
$display(
"  Expected: col0=%0d col1=%0d valid=%b",
expected0, expected1, expected_valid
);
errors = errors + 1;
end
else begin
$display(
"PASS TEST %0d: col0=%0d col1=%0d valid=%b",
test_number, c_col0, c_col1,
c_col0_valid
);
end
end
endtask

initial begin
clk = 0;
rst_n = 0;
load_weights = 0;

b00 = 0; b01 = 0;
b10 = 0; b11 = 0;

a_k0_in = 0;
a_k1_in = 0;
a_k0_valid = 0;
a_k1_valid = 0;
errors = 0;

repeat (2) @(posedge clk);
@(negedge clk);
rst_n = 1;

// ====================================
// MATRIX TEST 1
//
// A = [1 2; 3 4]
// B = [5 6; 7 8]
// C = [19 22; 43 50]
// ====================================

// Test 1: Load B weights
load_weights = 1;
b00 = 5; b01 = 6;
b10 = 7; b11 = 8;

check_after_edge(1, 0, 0, 0);

// Test 2: Start row 0
@(negedge clk);
load_weights = 0;
a_k0_in = 1;
a_k0_valid = 1;
a_k1_valid = 0;

check_after_edge(2, 0, 0, 0);

// Test 3: Complete row 0; start row 1
@(negedge clk);
a_k0_in = 3;
a_k1_in = 2;
a_k0_valid = 1;
a_k1_valid = 1;

check_after_edge(3, 19, 22, 1);

// Test 4: Complete row 1
@(negedge clk);
a_k0_valid = 0;
a_k1_in = 4;
a_k1_valid = 1;

check_after_edge(4, 43, 50, 1);

// Test 5: Idle
@(negedge clk);
a_k0_valid = 0;
a_k1_valid = 0;

check_after_edge(5, 43, 50, 0);

// ====================================
// MATRIX TEST 2
//
// A = [-2  5; 6 -1]
// B = [-1  2; 3 -4]
// C = [17 -24; -9 16]
// ====================================

// Test 6: Load replacement B weights
@(negedge clk);
load_weights = 1;

b00 = -1; b01 = 2;
b10 = 3;  b11 = -4;

check_after_edge(6, 43, 50, 0);

// Test 7: Start row 0
@(negedge clk);
load_weights = 0;
a_k0_in = -2;
a_k0_valid = 1;
a_k1_valid = 0;

check_after_edge(7, 43, 50, 0);

// Test 8: Complete row 0; start row 1
@(negedge clk);
a_k0_in = 6;
a_k1_in = 5;
a_k0_valid = 1;
a_k1_valid = 1;

check_after_edge(8, 17, -24, 1);

// Test 9: Complete row 1
@(negedge clk);
a_k0_valid = 0;
a_k1_in = -1;
a_k1_valid = 1;

check_after_edge(9, -9, 16, 1);

// Test 10: Idle
@(negedge clk);
a_k0_valid = 0;
a_k1_valid = 0;

check_after_edge(10, -9, 16, 0);

if (errors == 0)
$display("ALL 2x2 WS ARRAY TESTS PASSED");
else
$display("WS ARRAY FAILURES = %0d", errors);

$finish;
end

endmodule
