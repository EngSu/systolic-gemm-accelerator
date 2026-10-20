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