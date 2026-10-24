`timescale 1ns/1ps


module pe_ws_tb;

reg clk;
reg rst_n;

reg load_weight;
reg valid_in;

reg signed [15:0] weight_in;
reg signed [15:0] activation_in;
reg signed [31:0] psum_in;

wire signed [31:0] psum_out;
wire valid_out;

integer errors;

// ----------------------------------------
// Device Under Test
// ----------------------------------------

pe_ws #(
.DATA_WIDTH(16),
.ACC_WIDTH(32)
) dut (
.clk(clk),
.rst_n(rst_n),
.load_weight(load_weight),
.weight_in(weight_in),
.activation_in(activation_in),
.psum_in(psum_in),
.valid_in(valid_in),
.psum_out(psum_out),
.valid_out(valid_out)
);

// Clock period = 10 ns
always #5 clk = ~clk;

// ----------------------------------------
// Reusable output checker
// ----------------------------------------

task check_after_clock;
input integer test_number;
input signed [31:0] expected_psum;
input expected_valid;

begin
@(posedge clk);
#1;

if (psum_out !== expected_psum ||
valid_out !== expected_valid) begin

$display(
"FAIL TEST %0d: psum=%0d valid=%b, expected psum=%0d valid=%b",
test_number,
psum_out,
valid_out,
expected_psum,
expected_valid
);

errors = errors + 1;
end
else begin
$display(
"PASS TEST %0d: psum=%0d valid=%b",
test_number,
psum_out,
valid_out
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

load_weight = 0;
weight_in = 0;
activation_in = 0;
psum_in = 0;
valid_in = 0;
errors = 0;

// Reset
repeat (2) @(posedge clk);
@(negedge clk);
rst_n = 1;

// TEST 1: Load weight 3.
// A simultaneous valid input must be ignored.
load_weight = 1;
weight_in = 3;
activation_in = 9;
psum_in = 100;
valid_in = 1;

check_after_clock(1, 32'sd0, 1'b0);

// TEST 2: 5 + (2 * 3) = 11
@(negedge clk);
load_weight = 0;
activation_in = 2;
psum_in = 5;
valid_in = 1;

check_after_clock(2, 32'sd11, 1'b1);

// TEST 3: Reuse stored weight 3.
// 10 + (4 * 3) = 22
@(negedge clk);
activation_in = 4;
psum_in = 10;

check_after_clock(3, 32'sd22, 1'b1);

// TEST 4: Signed arithmetic.
// 11 + (-4 * 3) = -1
@(negedge clk);
activation_in = -4;
psum_in = 11;

check_after_clock(4, -32'sd1, 1'b1);

// TEST 5: Invalid input must not update output.
@(negedge clk);
valid_in = 0;
activation_in = 100;
psum_in = 100;

check_after_clock(5, -32'sd1, 1'b0);

// TEST 6: Replace weight with -2.
// Loading overrides simultaneous valid input.
@(negedge clk);
load_weight = 1;
weight_in = -2;
activation_in = 8;
psum_in = 8;
valid_in = 1;

check_after_clock(6, -32'sd1, 1'b0);

// TEST 7: Use the new negative weight.
// 7 + (-3 * -2) = 13
@(negedge clk);
load_weight = 0;
activation_in = -3;
psum_in = 7;

check_after_clock(7, 32'sd13, 1'b1);

// TEST 8: Asynchronous reset
@(negedge clk);
valid_in = 0;

#2;
rst_n = 0;

#1;

if (psum_out !== 32'sd0 ||
valid_out !== 1'b0) begin
$display("FAIL TEST 8: asynchronous reset");
errors = errors + 1;
end
else begin
$display("PASS TEST 8: asynchronous reset");
end

// TEST 9: Reject computation before weight reload.
@(negedge clk);
rst_n = 1;
load_weight = 0;
valid_in = 1;
activation_in = 2;
psum_in = 10;

check_after_clock(9, 32'sd0, 1'b0);

// TEST 10: Load a fresh weight after reset.
@(negedge clk);
load_weight = 1;
weight_in = 4;
valid_in = 0;

check_after_clock(10, 32'sd0, 1'b0);

// TEST 11: Compute using reloaded weight.
// 1 + (6 * 4) = 25
@(negedge clk);
load_weight = 0;
valid_in = 1;
activation_in = 6;
psum_in = 1;

check_after_clock(11, 32'sd25, 1'b1);

// ----------------------------------------
// Final results
// ----------------------------------------

if (errors == 0)
$display("ALL PE WS TESTS PASSED");
else
$display("PE WS TEST FAILURES = %0d", errors);

$finish;
end

endmodule
