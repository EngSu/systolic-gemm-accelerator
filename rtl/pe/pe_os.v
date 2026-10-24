
`timescale 1ns/1ps

module pe_os #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 32
)(
    input wire clk,
    input wire rst_n,

    input wire clear_acc,
    input wire valid_in,

    input wire signed [DATA_WIDTH-1:0] a_in,
    input wire signed [DATA_WIDTH-1:0] b_in,

    output reg signed [DATA_WIDTH-1:0] a_out,
    output reg signed [DATA_WIDTH-1:0] b_out,
    output reg valid_out,

    output reg signed [ACC_WIDTH-1:0] acc_out
);

// Full-width signed multiplication
wire signed [2*DATA_WIDTH-1:0] product;

assign product = a_in * b_in;

// Sign-extend product to accumulator width
wire signed [ACC_WIDTH-1:0] product_ext;

assign product_ext =
    {{(ACC_WIDTH-2*DATA_WIDTH)
      {product[2*DATA_WIDTH-1]}}, product};

// Registered operand forwarding
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        a_out     <= 0;
        b_out     <= 0;
        valid_out <= 0;
    end
    else begin
        a_out     <= a_in;
        b_out     <= b_in;
        valid_out <= valid_in;
    end
end

// Local output-stationary accumulation
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        acc_out <= 0;
    end
    else if (clear_acc) begin
        acc_out <= 0;
    end
    else if (valid_in) begin
        acc_out <= acc_out + product_ext;
    end
end

endmodule
