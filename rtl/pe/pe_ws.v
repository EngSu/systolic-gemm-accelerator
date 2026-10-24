
`timescale 1ns/1ps

module pe_ws #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 32
)(
    input wire clk,
    input wire rst_n,

    // Weight loading interface
    input wire load_weight,
    input wire signed [DATA_WIDTH-1:0] weight_in,

    // Arithmetic inputs
    input wire signed [DATA_WIDTH-1:0] activation_in,
    input wire signed [ACC_WIDTH-1:0] psum_in,
    input wire valid_in,

    // Registered outputs
    output reg signed [ACC_WIDTH-1:0] psum_out,
    output reg valid_out
);

    // ----------------------------------------
    // 1. Stationary weight storage
    // ----------------------------------------

    reg signed [DATA_WIDTH-1:0] weight_reg;
    reg weight_loaded;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_reg    <= 0;
            weight_loaded <= 0;
        end
        else if (load_weight) begin
            weight_reg    <= weight_in;
            weight_loaded <= 1'b1;
        end
    end

    // ----------------------------------------
    // 2. Signed multiplication
    // ----------------------------------------

    wire signed [2*DATA_WIDTH-1:0] product;

    assign product = activation_in * weight_reg;

    // Extend the signed product to accumulator width.
    wire signed [ACC_WIDTH-1:0] product_ext;

    assign product_ext = product;

    // ----------------------------------------
    // 3. Partial-sum computation and forwarding
    // ----------------------------------------

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            psum_out  <= 0;
            valid_out <= 0;
        end
        else if (load_weight) begin
            // Loading takes priority over computation.
            valid_out <= 0;
        end
        else if (valid_in && weight_loaded) begin
            psum_out  <= psum_in + product_ext;
            valid_out <= 1'b1;
        end
        else begin
            // Invalid output: retain psum_out.
            valid_out <= 0;
        end
    end

endmodule

