
`timescale 1ns/1ps

module pe_tb;

reg clk;
reg rst_n;

reg signed [15:0] a_in;
reg signed [15:0] b_in;
reg signed [31:0] acc_in;

wire signed [15:0] a_out;
wire signed [15:0] b_out;
wire signed [31:0] acc_out;

integer errors;

pe dut (
    .clk(clk),
    .rst_n(rst_n),
    .a_in(a_in),
    .b_in(b_in),
    .acc_in(acc_in),
    .a_out(a_out),
    .b_out(b_out),
    .acc_out(acc_out)
);

// 10 ns clock period
always #5 clk = ~clk;

initial begin
    clk = 0;
    rst_n = 0;
    errors = 0;

    a_in = 0;
    b_in = 0;
    acc_in = 0;

    // Hold reset for two rising clock edges
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst_n = 1;

    // TEST 1: 2 * 3 + 0 = 6
    a_in = 2;
    b_in = 3;
    acc_in = 0;

    @(posedge clk);
    #1;

    if (acc_out !== 32'sd6 ||
        a_out !== 16'sd2 ||
        b_out !== 16'sd3) begin
        $display("FAIL TEST 1");
        errors = errors + 1;
    end
    else begin
        $display("PASS TEST 1: acc_out = %0d", acc_out);
    end

    // TEST 2: 5 * 4 + 10 = 30
    @(negedge clk);
    a_in = 5;
    b_in = 4;
    acc_in = 10;

    @(posedge clk);
    #1;

    if (acc_out !== 32'sd30 ||
        a_out !== 16'sd5 ||
        b_out !== 16'sd4) begin
        $display("FAIL TEST 2");
        errors = errors + 1;
    end
    else begin
        $display("PASS TEST 2: acc_out = %0d", acc_out);
    end

    // TEST 3: -2 * 3 + 0 = -6
    @(negedge clk);
    a_in = -2;
    b_in = 3;
    acc_in = 0;

    @(posedge clk);
    #1;

    if (acc_out !== -32'sd6 ||
        a_out !== -16'sd2 ||
        b_out !== 16'sd3) begin
        $display("FAIL TEST 3");
        errors = errors + 1;
    end
    else begin
        $display("PASS TEST 3: acc_out = %0d", acc_out);
    end

    if (errors == 0)
        $display("ALL PE TESTS PASSED");
    else
        $display("PE TEST FAILURES = %0d", errors);

    $finish;
end

endmodule
