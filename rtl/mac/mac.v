////////////////////////////////////////////////////////////////////////////////
// Author:        Sumaia A
// Project:       systolic-gemm-accelerator
// Module:        mac
// Target:        Zynq-7000 XC7Z020 (ZedBoard), Vivado 2025.2
// Description:   Signed multiply-accumulate with a registered output:
//                acc_out <= acc_in + a*b, one clock of latency, async active-low reset.
//                Standalone building block; the PEs repeat this arithmetic inline.
// Notes:         Not instantiated by any other RTL in this repository.
//                ACC_WIDTH must be at least 2*DATA_WIDTH (product is sign-extended).
////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
module mac #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 32
)(
    input  wire clk,
    input  wire rst_n,

    input  wire signed [DATA_WIDTH-1:0] a,
    input  wire signed [DATA_WIDTH-1:0] b,
    input  wire signed [ACC_WIDTH-1:0]   acc_in,

    output reg  signed [ACC_WIDTH-1:0]   acc_out
);

wire signed [2*DATA_WIDTH-1:0] mult;
wire signed [ACC_WIDTH-1:0] mult_ext;

assign mult = a * b;
assign mult_ext = {{(ACC_WIDTH-2*DATA_WIDTH){mult[2*DATA_WIDTH-1]}}, mult};

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        acc_out <= 0;
    else
        acc_out <= acc_in + mult_ext;
end

endmodule