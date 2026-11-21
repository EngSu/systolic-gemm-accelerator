////////////////////////////////////////////////////////////////////////////////
// Author:        Sumaia A
// Project:       systolic-gemm-accelerator
// Module:        ws_chain_2
// Target:        Zynq-7000 XC7Z020 (ZedBoard), Vivado 2025.2
// Description:   Two pe_ws elements in series, forming one column of a
//                weight-stationary array. Stage 1 adds its product to stage 0's
//                registered partial sum.
// Notes:         Stage 0's sum is registered, so activation1_in must arrive one clock
//                after activation0_in.
//                Intermediate psum_stage0 is exported for verification only.
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module ws_chain_2 #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 32
)(
    input wire clk,
    input wire rst_n,

    // Both weights are loaded together.
    input wire load_weights,
    input wire signed [DATA_WIDTH-1:0] weight0_in,
    input wire signed [DATA_WIDTH-1:0] weight1_in,

    // Separate, scheduled activations for each stage.
    input wire signed [DATA_WIDTH-1:0] activation0_in,
    input wire signed [DATA_WIDTH-1:0] activation1_in,
    input wire valid0_in,
    input wire valid1_in,

    // Intermediate result, exposed for verification.
    output wire signed [ACC_WIDTH-1:0] psum_stage0,
    output wire valid_stage0,

    // Final chain output.
    output wire signed [ACC_WIDTH-1:0] result_out,
    output wire result_valid
);

    // ----------------------------------------
    // Stage 0: First stationary weight
    // ----------------------------------------

    pe_ws #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) pe0 (
        .clk(clk),
        .rst_n(rst_n),

        .load_weight(load_weights),
        .weight_in(weight0_in),

        .activation_in(activation0_in),
        .psum_in({ACC_WIDTH{1'b0}}),
        .valid_in(valid0_in),

        .psum_out(psum_stage0),
        .valid_out(valid_stage0)
    );

    // ----------------------------------------
    // Stage 1: Second stationary weight
    // ----------------------------------------

    wire stage1_valid;

    assign stage1_valid = valid_stage0 & valid1_in;

    pe_ws #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) pe1 (
        .clk(clk),
        .rst_n(rst_n),

        .load_weight(load_weights),
        .weight_in(weight1_in),

        .activation_in(activation1_in),
        .psum_in(psum_stage0),
        .valid_in(stage1_valid),

        .psum_out(result_out),
        .valid_out(result_valid)
    );

endmodule

