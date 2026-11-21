////////////////////////////////////////////////////////////////////////////////
// Author:        Sumaia A
// Project:       systolic-gemm-accelerator
// Module:        pe
// Target:        Zynq-7000 XC7Z020 (ZedBoard), Vivado 2025.2
// Description:   First-generation processing element with fixed 16-bit operands and a
//                32-bit partial sum. Forwards a and b one clock later and registers
//                acc_in + a*b into acc_out.
// Notes:         No valid or clear control and no local accumulator.
//                Superseded by pe_os (output stationary) and pe_ws (weight stationary).
////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module pe (
    input wire clk,
    input wire rst_n,

    input wire signed [15:0] a_in,
    input wire signed [15:0] b_in,
    input wire signed [31:0] acc_in,

    output reg signed [15:0] a_out,
    output reg signed [15:0] b_out,
    output reg signed [31:0] acc_out
);

wire signed [31:0] mac_result;

// MAC operation
assign mac_result = acc_in + (a_in * b_in);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        a_out   <= 0;
        b_out   <= 0;
        acc_out <= 0;
    end
    else begin
        // forward signals (this is systolic behavior)
        a_out <= a_in;
        b_out <= b_in;

        // accumulate result
        acc_out <= mac_result;
    end
end

endmodule