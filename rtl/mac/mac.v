`timescale 1ns/1ps
/////////////////////////////////////////////////////////////////////////////////
// Company: York University
// Engineer: Sumaia A
// Supervisor: Prof. Sebastian Magierowski
//
// Create Date: 06/20/2024
// Design Name: MAC Unit for Systolic Array Hardware Accelerator
// Module Name: mac
// Project Name: fpga-accelerator-rtl
//
// Target Devices: AMD Zynq-7000 SoC (XC7Z020 - ZedBoard)
//
// Tool Versions: Vivado 2025.x
//
// Description:
// This module implements a Multiply-Accumulate (MAC) unit, which is the
// fundamental computation block for a systolic array-based hardware accelerator.
//
// Functionality:
// - Performs signed multiplication of inputs a and b
// - Accumulates result with previous partial sum (acc_in)
// - Produces registered output acc_out (1-cycle latency)
//
// This MAC serves as the building block for:
// - Processing Element (PE)
// - 2×2 and 4×4 Systolic Arrays
// - Neural Network Acceleration Units
//
// Architecture Notes:
// - Fully synchronous design (posedge clock)
// - Active-low reset
// - Signed arithmetic for DSP-style workloads
//
// Revision:
// Revision 0.01 - File Created
// Revision 0.02 - Updated for systolic-array integration readiness
//
// Additional Comments:
// - This module is designed for reuse in scalable systolic architectures
// - Will be extended into PE with data forwarding in next iteration
/////////////////////////////////////////////////////////////////////////////////
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