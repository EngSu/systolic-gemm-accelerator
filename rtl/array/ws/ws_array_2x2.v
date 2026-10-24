
`timescale 1ns/1ps

module ws_array_2x2 #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 32
)(
    input wire clk,
    input wire rst_n,

    // Preload all four B matrix weights.
    input wire load_weights,
    input wire signed [DATA_WIDTH-1:0] b00,
    input wire signed [DATA_WIDTH-1:0] b01,
    input wire signed [DATA_WIDTH-1:0] b10,
    input wire signed [DATA_WIDTH-1:0] b11,

    // Scheduled activations from matrix A.
    input wire signed [DATA_WIDTH-1:0] a_k0_in,
    input wire signed [DATA_WIDTH-1:0] a_k1_in,
    input wire a_k0_valid,
    input wire a_k1_valid,

    // Streaming results: one output per column.
    output wire signed [ACC_WIDTH-1:0] c_col0,
    output wire signed [ACC_WIDTH-1:0] c_col1,
    output wire c_col0_valid,
    output wire c_col1_valid
);

    // ----------------------------------------
    // Column 0: B[0][0], B[1][0]
    // ----------------------------------------

    ws_chain_2 #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) col0 (
        .clk(clk),
        .rst_n(rst_n),

        .load_weights(load_weights),
        .weight0_in(b00),
        .weight1_in(b10),

        .activation0_in(a_k0_in),
        .activation1_in(a_k1_in),
        .valid0_in(a_k0_valid),
        .valid1_in(a_k1_valid),

        .psum_stage0(),
        .valid_stage0(),

        .result_out(c_col0),
        .result_valid(c_col0_valid)
    );

    // ----------------------------------------
    // Column 1: B[0][1], B[1][1]
    // ----------------------------------------

    ws_chain_2 #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) col1 (
        .clk(clk),
        .rst_n(rst_n),

        .load_weights(load_weights),
        .weight0_in(b01),
        .weight1_in(b11),

        .activation0_in(a_k0_in),
        .activation1_in(a_k1_in),
        .valid0_in(a_k0_valid),
        .valid1_in(a_k1_valid),

        .psum_stage0(),
        .valid_stage0(),

        .result_out(c_col1),
        .result_valid(c_col1_valid)
    );

endmodule


