`timescale 1ns/1ps

module mac_tb;

reg clk;
reg rst_n;

reg signed [15:0] a;
reg signed [15:0] b;
reg signed [31:0] acc_in;

wire signed [31:0] acc_out;

integer errors;
integer i;
reg signed [31:0] exp;

// DUT
mac dut (
    .clk(clk),
    .rst_n(rst_n),
    .a(a),
    .b(b),
    .acc_in(acc_in),
    .acc_out(acc_out)
);

// clock
always #5 clk = ~clk;

// reference model (NO TASK DEPENDENCY ISSUES)
function signed [31:0] expected;
    input signed [15:0] a;
    input signed [15:0] b;
    input signed [31:0] acc;
begin
    expected = acc + (a * b);
end
endfunction

initial begin
    clk = 0;
    errors = 0;

    // reset
    rst_n = 0;
    a = 0;
    b = 0;
    acc_in = 0;

    repeat(2) @(posedge clk);
    rst_n = 1;

    // ---------------------------
    // TEST 1
    // ---------------------------
    a = 2; b = 3; acc_in = 0;
    @(posedge clk);
    #1;
    exp = expected(2,3,0);

    if (acc_out !== exp) begin
        $display("FAIL exp=%0d got=%0d", exp, acc_out);
        errors = errors + 1;
    end else
        $display("PASS %0d", acc_out);

    // ---------------------------
    // TEST 2
    // ---------------------------
    a = 5; b = 4; acc_in = 10;
    @(posedge clk);
    #1;
    exp = expected(5,4,10);

    if (acc_out !== exp) begin
        $display("FAIL exp=%0d got=%0d", exp, acc_out);
        errors = errors + 1;
    end else
        $display("PASS %0d", acc_out);

    // ---------------------------
    // TEST 3
    // ---------------------------
    a = -2; b = 3; acc_in = 0;
    @(posedge clk);
    #1;
    exp = expected(-2,3,0);

    if (acc_out !== exp) begin
        $display("FAIL exp=%0d got=%0d", exp, acc_out);
        errors = errors + 1;
    end else
        $display("PASS %0d", acc_out);

    // ---------------------------
    // RESULT
    // ---------------------------
    repeat(2) @(posedge clk);

    if (errors == 0)
        $display("ALL TESTS PASSED");
    else
        $display("FAILURES = %0d", errors);

    $finish;
end

endmodule