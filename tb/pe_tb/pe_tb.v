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

always #5 clk = ~clk;

initial begin
    clk = 0;
    rst_n = 0;

    a_in = 0;
    b_in = 0;
    acc_in = 0;

    repeat(2) @(posedge clk);
    rst_n = 1;

    // test 1
    a_in = 2; b_in = 3; acc_in = 0;
    @(posedge clk);

    $display("acc_out = %0d", acc_out);

    // test 2
    a_in = 5; b_in = 4; acc_in = 10;
    @(posedge clk);

    $display("acc_out = %0d", acc_out);

    $finish;
end

endmodule