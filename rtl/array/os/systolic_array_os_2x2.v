
`timescale 1ns/1ps

module systolic_array_os_2x2 #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 32
)(
    input wire clk,
    input wire rst_n,
    input wire clear_acc,

    // A enters horizontally from the left
    input wire signed [DATA_WIDTH-1:0] a_row0,
    input wire signed [DATA_WIDTH-1:0] a_row1,
    input wire a_valid0,
    input wire a_valid1,

    // B enters vertically from the top
    input wire signed [DATA_WIDTH-1:0] b_col0,
    input wire signed [DATA_WIDTH-1:0] b_col1,
    input wire b_valid0,
    input wire b_valid1,

    // Four stationary output accumulators
    output wire signed [ACC_WIDTH-1:0] c00,
    output wire signed [ACC_WIDTH-1:0] c01,
    output wire signed [ACC_WIDTH-1:0] c10,
    output wire signed [ACC_WIDTH-1:0] c11
);

    // ----------------------------------------
    // Operand forwarding connections
    // ----------------------------------------

    wire signed [DATA_WIDTH-1:0] a00_to_01;
    wire signed [DATA_WIDTH-1:0] a10_to_11;

    wire signed [DATA_WIDTH-1:0] b00_to_10;
    wire signed [DATA_WIDTH-1:0] b01_to_11;

    // ----------------------------------------
    // Independent validity forwarding
    // ----------------------------------------

    reg a_valid0_d;
    reg a_valid1_d;
    reg b_valid0_d;
    reg b_valid1_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_valid0_d <= 0;
            a_valid1_d <= 0;
            b_valid0_d <= 0;
            b_valid1_d <= 0;
        end
        else begin
            a_valid0_d <= a_valid0;
            a_valid1_d <= a_valid1;
            b_valid0_d <= b_valid0;
            b_valid1_d <= b_valid1;
        end
    end

    // ----------------------------------------
    // PE (0,0) — upper left
    // ----------------------------------------

    pe_os #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) pe00 (
        .clk(clk),
        .rst_n(rst_n),
        .clear_acc(clear_acc),

        .valid_in(a_valid0 & b_valid0),
        .a_in(a_row0),
        .b_in(b_col0),

        .a_out(a00_to_01),
        .b_out(b00_to_10),
        .valid_out(),
        .acc_out(c00)
    );

    // ----------------------------------------
    // PE (0,1) — upper right
    // ----------------------------------------

    pe_os #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) pe01 (
        .clk(clk),
        .rst_n(rst_n),
        .clear_acc(clear_acc),

        .valid_in(a_valid0_d & b_valid1),
        .a_in(a00_to_01),
        .b_in(b_col1),

        .a_out(),
        .b_out(b01_to_11),
        .valid_out(),
        .acc_out(c01)
    );

    // ----------------------------------------
    // PE (1,0) — lower left
    // ----------------------------------------

    pe_os #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) pe10 (
        .clk(clk),
        .rst_n(rst_n),
        .clear_acc(clear_acc),

        .valid_in(a_valid1 & b_valid0_d),
        .a_in(a_row1),
        .b_in(b00_to_10),

        .a_out(a10_to_11),
        .b_out(),
        .valid_out(),
        .acc_out(c10)
    );

    // ----------------------------------------
    // PE (1,1) — lower right
    // ----------------------------------------

    pe_os #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) pe11 (
        .clk(clk),
        .rst_n(rst_n),
        .clear_acc(clear_acc),

        .valid_in(a_valid1_d & b_valid1_d),
        .a_in(a10_to_11),
        .b_in(b01_to_11),

        .a_out(),
        .b_out(),
        .valid_out(),
        .acc_out(c11)
    );

endmodule

