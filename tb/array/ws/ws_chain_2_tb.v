`timescale 1ns/1ps


module ws_chain_2_tb;

reg clk;
reg rst_n;
reg load_weights;

reg signed [15:0] weight0_in;
reg signed [15:0] weight1_in;

reg signed [15:0] activation0_in;
reg signed [15:0] activation1_in;

reg valid0_in;
reg valid1_in;

wire signed [31:0] psum_stage0;
wire valid_stage0;

wire signed [31:0] result_out;
wire result_valid;

integer errors;

// Device Under Test
ws_chain_2 dut (
.clk(clk),
.rst_n(rst_n),
.load_weights(load_weights),
.weight0_in(weight0_in),
.weight1_in(weight1_in),
.activation0_in(activation0_in),
.activation1_in(activation1_in),
.valid0_in(valid0_in),
.valid1_in(valid1_in),
.psum_stage0(psum_stage0),
.valid_stage0(valid_stage0),
.result_out(result_out),
.result_valid(result_valid)
);

// 10 ns clock period
always #5 clk = ~clk;

// ----------------------------------------
// Reusable checker
// ----------------------------------------

task check_after_edge;
input integer test_number;
input signed [31:0] expected_stage0;
input expected_valid0;
input signed [31:0] expected_result;
input expected_valid1;

begin
@(posedge clk);
#1;

if (psum_stage0 !== expected_stage0 ||
valid_stage0 !== expected_valid0 ||
result_out !== expected_result ||
result_valid !== expected_valid1) begin

$display("FAIL TEST %0d", test_number);
$display("  Stage 0: got %0d valid=%b",
psum_stage0, valid_stage0);
$display("  Expected: %0d valid=%b",
expected_stage0, expected_valid0);
$display("  Result:  got %0d valid=%b",
result_out, result_valid);
$display("  Expected: %0d valid=%b",
expected_result, expected_valid1);

errors = errors + 1;
end
else begin
$display(
"PASS TEST %0d: stage0=%0d valid0=%b, result=%0d valid=%b",
test_number,
psum_stage0,
valid_stage0,
result_out,
result_valid
);
end
end
endtask

// ----------------------------------------
// Test sequence
// ----------------------------------------

initial begin
clk = 0;
rst_n = 0;
load_weights = 0;

weight0_in = 0;
weight1_in = 0;
activation0_in = 0;
activation1_in = 0;
valid0_in = 0;
valid1_in = 0;
errors = 0;

// Initialize with reset asserted.
repeat (2) @(posedge clk);
@(negedge clk);
rst_n = 1;

// TEST 1: Load weights 5 and 7.
load_weights = 1;
weight0_in = 5;
weight1_in = 7;

check_after_edge(1, 0, 0, 0, 0);

// TEST 2: First vector, first stage.
// 1 * 5 = 5
@(negedge clk);
load_weights = 0;
activation0_in = 1;
valid0_in = 1;
valid1_in = 0;

check_after_edge(2, 5, 1, 0, 0);

// TEST 3:
// PE1 finishes vector 0: 5 + 27 = 19.
// PE0 starts vector 1: 35 = 15.
@(negedge clk);
activation0_in = 3;
valid0_in = 1;
activation1_in = 2;
valid1_in = 1;

check_after_edge(3, 15, 1, 19, 1);

// TEST 4:
// PE1 finishes vector 1: 15 + 4*7 = 43.
@(negedge clk);
valid0_in = 0;
activation1_in = 4;
valid1_in = 1;

check_after_edge(4, 15, 0, 43, 1);

// TEST 5: Pipeline idle.
// Outputs hold; validity becomes zero.
@(negedge clk);
valid0_in = 0;
valid1_in = 0;

check_after_edge(5, 15, 0, 43, 0);

// TEST 6: Reload two negative/positive weights.
@(negedge clk);
load_weights = 1;
weight0_in = -3;
weight1_in = 2;

check_after_edge(6, 15, 0, 43, 0);

// TEST 7:
// First stage: 4 * (-3) = -12.
@(negedge clk);
load_weights = 0;
activation0_in = 4;
valid0_in = 1;
valid1_in = 0;

check_after_edge(7, -12, 1, 43, 0);

// TEST 8:
// Second stage: -12 + (5 * 2) = -2.
@(negedge clk);
valid0_in = 0;
activation1_in = 5;
valid1_in = 1;

check_after_edge(8, -12, 0, -2, 1);

// TEST 9: Pipeline idle after negative result.
@(negedge clk);
valid1_in = 0;

check_after_edge(9, -12, 0, -2, 0);

// ----------------------------------------
// Final summary
// ----------------------------------------

if (errors == 0)
$display("ALL WS CHAIN TESTS PASSED");
else
$display("WS CHAIN FAILURES = %0d", errors);

$finish;
end

endmodule
